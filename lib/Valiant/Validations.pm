package Valiant::Validations;

use Moo;
use Moo::_Utils;
use Module::Runtime 'use_module';
use String::CamelCase 'camelize';

require Moo::Role;

sub default_roles { 'Valiant::Validatable' }
sub default_meta { 'Valiant::Meta' }
sub default_validator_namepart { 'Validator' }
sub default_collection_class { 'Valiant::Validator::Collection' }

sub import {
  my $class = shift;
  my $target = caller;
  my $meta = use_module($class->default_meta)->new;

  Moo::Role->apply_roles_to_package($target, $class->default_roles);

  _install_coderef "${target}::validates" => "Valiant::Meta::validate" => sub { $class->validates($target, $meta, @_) };
  _install_coderef "${target}::validates_with" => "Valiant::Meta::validates_with" => sub { $class->validates_with($target, $meta, @_) };
  _install_coderef "${target}::validates_each" => "Valiant::Meta::validates_each" => sub { $class->validates_each($target, $meta, @_) };

  eval "package ${target}; sub validations { shift->maybe::next::method(\@_) } ";
  eval "package ${target}; sub ancestors { shift->maybe::next::method(\@_) } ";

  my $around = \&{"${target}::around"};
  $around->(validations => sub {
      my ($orig, $self) = @_;
      return ($self->$orig, $meta->validations->all);
  });
  $around->(ancestors => sub {
      my ($orig, $self) = @_;
      return ($self->$orig, $target);
  });
}

sub _validates_coderef {
  my ($class, $target, $meta, $coderef, %options) = @_;
  $meta->validations->push([$coderef, \%options]);
}

sub _is_reserved_option_key {
  my ($class, $key) = @_;
  return 1 if $key eq 'if' || $key eq 'unless' || $key eq 'on'
    || $key eq 'strict' || $key eq 'allow_blank' || $key eq 'allow_undef'
    || $key eq 'message';
  return 0;
}

sub _prepare_validator_packages {
  my ($class, $target, $key) = @_;
  return (
    $class->_normalize_validator_package($target, camelize($key)),
    'Valiant::ValidatorX::'.camelize($key), # Look here first in case someday we have XS versions of the built-ins
    'Valiant::Validator::'.camelize($key),
  );
}

sub _validator_package {
  my ($class, $target, $key) = @_;
  my @validator_packages = $class->_prepare_validator_packages($target, $key);
  my ($validator_package, @rest) = grep {
    eval { use_module $_ } || do {
      if($@=~m/^Can't locate/) {
        warn "Can't find $_ in \@INC\n" if $ENV{VALIANT_DEBUG};
        0;
      } else {
        die $@;
      }
    }
  }  @validator_packages;
  die "'$key' is not a validator" unless $validator_package;
  return $validator_package;
}

sub _create_validator {
  my ($class, $validator_package, $attributes, $args) = @_;
  my @args = (ref($args)||'') eq 'HASH' ?
    (attributes=>$attributes, %$args) :
    ($args, $attributes);
  return $validator_package->new(@args);
}

sub validates {
  my ($class, $target, $meta, @validation_proto) = @_;

  # If its a simple coderef validator just add it and return
  if(ref($validation_proto[0]||'') eq 'CODE') {
    $class->_validates_coderef($target, $meta, @validation_proto);
    return;
  }

  # handle a list of attributes with validations
  my $attributes = shift @validation_proto;
  my @options = @validation_proto;
  my @attributes = ref($attributes||'') eq 'ARRAY' 
    ? @$attributes : ($attributes);

  # We want to preserve the order of validators while stripping out global_options
  my (@validator_info, %global_options) = ();
  while(@options) {
    my ($key, $args) = (shift @options, shift @options);
    if($class->_is_reserved_option_key($key)) {
      $global_options{$key} = $args;
    } else {
      push @validator_info, [$key, $args];
    }
  }
  my @validators = ();
  foreach my $info(@validator_info) {
    my ($package_part, $args) = @$info;
    my $validator_package = $class->_validator_package($target, $package_part);

    # merge global options into args
    $args->{strict} = 1 if $global_options{strict} and !exists $args->{strict};
    $args->{allow_undef} = 1 if $global_options{allow_undef} and !exists $args->{allow_undef};
    $args->{allow_blank} = 1 if $global_options{allow_blank} and !exists $args->{allow_blank};

    foreach my $opt(qw(if unless on)) {
      next unless my $val = $global_options{$opt};
      my @val = (ref($val)||'') eq 'ARRAY' ? @$val : ($val);
      if(exists $args->{$opt}) {
        my $current = $args->{$opt};
        my @current = (ref($current)||'') eq 'ARRAY' ? @$current : ($current);
        @val = (@current, @val);
      }
      $args->{$opt} = \@val;
    }
    
    push @validators, $class->_create_validator($validator_package,\@attributes, $args);
  }
  my $coderef = sub { $_->validate(@_) foreach @validators };
  $class->_validates_coderef($target, $meta, $coderef); 
}

sub validates_each {
  my ($class, $target, $meta, @proto) = @_;
  my $coderef = pop @proto;
  @proto = @{$proto[0]} if ref($proto[0]) eq 'ARRAY';
  foreach my $attr (@proto) {
    my $coderef_each = sub {
      my $self = shift; 
      return $coderef->($self, $attr, $self->$attr);
    };
    $class->_validates_coderef($target, $meta, $coderef_each);  
  }
}

sub _normalize_validator_package {
  my ($class, $target, $with) = @_;
  my ($prefix, $package) = ($with =~m/^(\+?)(.+)$/);
  unless($prefix eq '+') {
    my @parts = split '::', $target; pop @parts;
    $package = join '::', @parts, $class->default_validator_namepart, $package;
  }
  return $package;
}

sub _strip_reserved_options {
  my ($class, %options) = @_;
  my %reserved = ();
  foreach my $key (keys %options) {
    if($class->_is_reserved_option_key($key)) {
      $reserved{$key} = delete $options{$key};
    }
  }
  return %reserved;
}

# TODO this needs to handle if unless on 
sub validates_with {
  my ($class, $target, $meta, $validators_proto, %options) = @_;
  my %reserved = $class->_strip_reserved_options(%options);
  my @with = ref($validators_proto) eq 'ARRAY' ? 
    @{$validators_proto} : ($validators_proto);
  my @validators = ();
  foreach my $with (@with) {
    my $package = $class->_normalize_validator_package($target, $with);
    my $validator = eval {
      use_module($package);
      $package->new(%options);
    } || do { die $@ };
    push @validators, $validator; 
  }
  my $collection = use_module($class->default_collection_class)
    ->new(validators=>\@validators, %reserved);
  $class->_validates_coderef($target, $meta, sub { $collection->validate(@_) }); 
}

1;

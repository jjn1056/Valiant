package Valiant::Validations;

use Moo;
use Moo::_Utils;
use Module::Runtime 'use_module';
use String::CamelCase 'camelize';

require Moo::Role;

sub default_roles { 'Valiant::Validatable' }
sub default_meta { 'Valiant::Meta' }
sub default_validator_namepart { 'Validator' }

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
    'Valiant::Validator::'.camelize($key),
    'Valiant::ValidatorX::'.camelize($key),
  );
}

sub _validator_package {
  my ($class, $target, $key) = @_;
  my @validator_packages = $class->_prepare_validator_packages($target, $key);
  my ($validator_package, @rest) = grep {
    eval { use_module $_ } || do {
      if($ENV{VALIANT_DEBUG}) {
        warn $@=~m/^Can't locate/ ? "Can't find $_ in \@INC\n" : $@;
        0;
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

  # We want to preserve the order of validators
  my (@validators, %global_options) = ();
  while(@options) {
    my ($key, $value) = (shift @options, shift @options);
    if($class->_is_reserved_option_key($key)) {
      $global_options{$key} = $value;
      next;
    }
    my $validator_package = $class->_validator_package($target, $key);
    push @validators, $class->_create_validator($validator_package,\@attributes, $value);
  }
  my $coderef = sub { $_->validate(@_) foreach @validators };
  $class->validates_with($target, $meta, '+Valiant::Validator::With', cb=>$coderef, attributes=>\@attributes, %global_options);

  # $class->_validates_coderef($target, $meta, $coderef, %global_options);
  #  $meta->validations->push([$coderef, \%global_options]);

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

# TODO this needs to handle if unless on
sub validates_with {
  my ($class, $target, $meta, $validators_proto, %options) = @_;
  my @with = ref($validators_proto) eq 'ARRAY' ? 
    @{$validators_proto} : ($validators_proto);
  foreach my $with (@with) {
    my $package = $class->_normalize_validator_package($target, $with);
    my $validator = use_module($package)->new(%options);
    my $validator_coderef = sub { $validator->validate(@_) };
    $class->_validates_coderef($target, $meta, $validator_coderef, %options);  
  }
}

1;

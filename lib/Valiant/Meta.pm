package Valiant::Meta;

use Moo;
use Data::Perl qw/array/;
use String::CamelCase 'camelize';
use Module::Runtime 'use_module';

sub default_validator_namepart { 'Validator' }
sub default_collection_class { 'Valiant::Validator::Collection' }

has validations => (
  is => 'ro',
  required => 1,
  default => sub { array() },
);

has target => (is=>'ro', required=>1);

sub _validates_coderef {
  my ($self, $coderef, %options) = @_;
  $self->validations->push([$coderef, \%options]);
}

sub _is_reserved_option_key {
  my ($self, $key) = @_;
  return 1 if $key eq 'if' || $key eq 'unless' || $key eq 'on'
    || $key eq 'strict' || $key eq 'allow_blank' || $key eq 'allow_undef'
    || $key eq 'message' || $key eq 'list';
  return 0;
}

sub _prepare_validator_packages {
  my ($self, $key) = @_;
  return (
    $self->_normalize_validator_package(camelize($key)),
    'Valiant::ValidatorX::'.camelize($key), # Look here first in case someday we have XS versions of the built-ins
    'Valiant::Validator::'.camelize($key),
  );
}

sub _validator_package {
  my ($self, $key) = @_;
  my @validator_packages = $self->_prepare_validator_packages($key);
  my ($validator_package, @rest) = grep {
    eval { use_module $_ } || do {
      # This regexp matches too much...
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
  my ($self, $validator_package, $attributes, $args) = @_;
  my @args = (ref($args)||'') eq 'HASH' ?
    (attributes=>$attributes, %$args) :
    ($args, $attributes);
  return $validator_package->new(@args);
}

sub validates {
  my ($self, @validation_proto) = @_;

  # If its a simple coderef validator just add it and return
  if(ref($validation_proto[0]||'') eq 'CODE') {
    $self->_validates_coderef(@validation_proto);
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
    if($self->_is_reserved_option_key($key)) {
      $global_options{$key} = $args;
    } else {
      push @validator_info, [$key, $args];
    }
  }
  my @validators = ();
  foreach my $info(@validator_info) {
    my ($package_part, $args) = @$info;
    my $validator_package = $self->_validator_package($package_part);

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
    
    push @validators, $self->_create_validator($validator_package,\@attributes, $args);
  }
  my $coderef = sub { $_->validate(@_) foreach @validators };
  $self->_validates_coderef($coderef, %global_options); 
}

sub validates_each {
  my ($self, @proto) = @_;
  my $coderef = pop @proto;
  @proto = @{$proto[0]} if ref($proto[0]) eq 'ARRAY';
  foreach my $attr (@proto) {
    my $coderef_each = sub {
      my $object = shift;
      return $coderef->($object, $attr, $object->$attr); # TODO might need to call 'read_attribute_for_validation'
    };
    $self->_validates_coderef($coderef_each);  
  }
}

sub _normalize_validator_package {
  my ($self, $with) = @_;
  my ($prefix, $package) = ($with =~m/^(\+?)(.+)$/);
  unless($prefix eq '+') {
    my @parts = split '::', $self->target; pop @parts;
    $package = join '::', @parts, $self->default_validator_namepart, $package;
  }
  return $package;
}

sub _strip_reserved_options {
  my ($self, %options) = @_;
  my %reserved = ();
  foreach my $key (keys %options) {
    if($self->_is_reserved_option_key($key)) {
      $reserved{$key} = delete $options{$key};
    }
  }
  return %reserved;
}

sub validates_with {
  my ($self, $validators_proto, %options) = @_;
  my %reserved = $self->_strip_reserved_options(%options);
  my @with = ref($validators_proto) eq 'ARRAY' ? 
    @{$validators_proto} : ($validators_proto);
  my @validators = ();
  foreach my $with (@with) {
    my $package = $self->_normalize_validator_package($with);
    my $validator = eval {
      use_module($package);
      $package->new(%options);
    } || do { die $@ };
    push @validators, $validator; 
  }
  my $collection = use_module($self->default_collection_class)
    ->new(validators=>\@validators, %reserved);
  $self->_validates_coderef(sub { $collection->validate(@_) }); 
}

sub validate {
  my ($self, $object, %args) = @_;
  foreach my $validation ($self->validations->all) {
    my %validation_args = (%{$validation->[1]}, %args);
    $validation->[0]($object, \%validation_args);
  }
  return $object->errors->size ? 0 : 1
}

1;

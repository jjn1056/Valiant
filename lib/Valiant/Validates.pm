package Valiant::Validates;

use Moo::Role;
use Module::Runtime 'use_module';
use String::CamelCase 'camelize';
use Scalar::Util 'blessed';

with 'Valiant::Translation';

my @validations;
sub validations {
  my ($class, $arg) = @_;
  $class = ref($class) if ref($class);
  my $varname = "${class}::validations";

  no strict "refs";
  push @$varname, $arg if defined($arg);

  return @$varname,
    map { $_->validations } 
    grep { $_->can('validations') }
      $class->ancestors;
}

sub errors_class { 'Valiant::Errors' }

has 'errors' => (
  is => 'ro',
  init_arg => undef,
  lazy => 1,
  default => sub {
    return use_module($_[0]->errors_class)
      ->new(object=>$_[0], i18n=>$_[0]->i18n);
  },
);

has 'validated' => (is=>'rw', required=>1, init_args=>undef, default=>0);

sub default_validator_namepart { 'Validator' }
sub default_collection_class { 'Valiant::Validator::Collection' }

sub read_attribute_for_validation {
  my ($self, $attribute) = @_;
  return unless defined $attribute;
  return my $value = $self->$attribute
    if $self->can($attribute);
}

sub _validates_coderef {
  my ($self, $coderef, %options) = @_;
  $self->validations([$coderef, \%options]);
}

sub _is_reserved_option_key {
  my ($key) = @_;
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
      # This regexp matches too much... We need to add the package
      # path here just the path delim will vary from platform to platform
      if($@=~m/^Can't locate/) {
        warn "Can't find $_ in \@INC\n" if $ENV{VALIANT_DEBUG};
        0;
      } else {
        die $@;
      }
    }
  }  @validator_packages;
  die "'$key' is not a validator" unless $validator_package;
  warn "Found $validator_package in \@INC\n" if $ENV{VALIANT_DEBUG};
  return $validator_package;
}

sub _create_validator {
  my ($self, $validator_package, $args) = @_;
  return $validator_package->new($args);
}

sub validates {
  my ($self, @validation_proto) = @_;

  # handle a list of attributes with validations
  my $attributes = shift @validation_proto;
  $attributes = [$attributes] unless ref $attributes;
  my @options = @validation_proto;

  # We want to preserve the order of validators while stripping out global_options
  my (@validator_info, %global_options) = ();
  while(@options) {
    my $args;
    my $key = shift(@options);
    if(blessed($key) && $key->can('check')) { # This bit allows for Type::Tiny instead of a validator => \%params setup
      $args = { constraint => $key };
      $key = 'check';
      if((ref($options[0])||'') eq 'HASH') {
        my $base_args = shift(@options);
        $args = +{ %$args, %$base_args };
      }
    } elsif((ref($key)||'') eq 'CODE') { # This bit allows for callbacks instead of a validator => \%params setup
      $args = { cb => $key };
      $key = 'with';
      if((ref($options[0])||'') eq 'HASH') {
        my $base_args = shift(@options);
        $args = +{ %$args, %$base_args };
      }
    } else { # Otherwise its a normal validator with params
      $args = shift(@options);
    }

    if(_is_reserved_option_key($key)) {
      $global_options{$key} = $args;
    } else {
      push @validator_info, [$key, $args];
    }
  }

  my @validators = ();
  foreach my $info(@validator_info) {
    my ($package_part, $args) = @$info;
    my $validator_package = $self->_validator_package($package_part);

    unless((ref($args)||'') eq 'HASH') {
      $args = $validator_package->normalize_shortcut($args);
    }

    # merge global options into args
    $args->{strict} = 1 if $global_options{strict} and !exists $args->{strict};
    $args->{allow_undef} = 1 if $global_options{allow_undef} and !exists $args->{allow_undef};
    $args->{allow_blank} = 1 if $global_options{allow_blank} and !exists $args->{allow_blank};
    $args->{message} = $global_options{message} if exists $global_options{message} and !exists $args->{message};

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
    
    $args->{attributes} = $attributes;

    push @validators, $self->_create_validator($validator_package, $args);
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
  return $package if $prefix eq '+';

  my @parts = split '::',( ref($self) || $self);
  my @packages = (join '::', @parts, $self->default_validator_namepart, $package);
  pop @parts;
  push @packages, join '::', @parts, $self->default_validator_namepart, $package;
  return @packages;
}

sub _strip_reserved_options {
  my (%options) = @_;
  my %reserved = ();
  foreach my $key (keys %options) {
    if(_is_reserved_option_key($key)) {
      $reserved{$key} = delete $options{$key};
    }
  }
  return %reserved;
}

sub validates_with {
  my ($self, $validators_proto, %options) = @_;
  my %reserved = _strip_reserved_options(%options);
  my @with = ref($validators_proto) eq 'ARRAY' ? 
    @{$validators_proto} : ($validators_proto);

  my @validators = ();
  VALIDATOR_WITHS: foreach my $with (@with) {
    my @possible_packages = $self->_normalize_validator_package($with);
    if( (ref($with)||'') eq 'CODE') {
      push @validators, [$with, \%options];
      next VALIDATOR_WITHS;
    }
    foreach my $package(@possible_packages) {
      my $found_package = eval {
        use_module($package);
      } || do {
        if($@=~m/^Can't locate/) {
          warn "Can't find $_ in \@INC\n" if $ENV{VALIANT_DEBUG};
          0;
        } else {
          die $@; # Probably a syntax error in the code of $package
        }
      };
      if($found_package) {
        push @validators, $package->new(%options);
        next VALIDATOR_WITHS; # Only load the first one found
      }
    }
  }
  my $collection = use_module($self->default_collection_class)
    ->new(validators=>\@validators, %reserved);
  $self->_validates_coderef(sub { $collection->validate(@_) }); 
}

sub valid {
  my $self = shift;
  $self->validate(@_) if @_ || !$self->validated;
  return $self->errors->size ? 0:1;
}

sub invalid { shift->valid(@_) ? 0:1 }

sub clear_validated {
  my $self = shift;
  $self->errors->clear;
  $self->validated(0);
}

sub validate {
  my ($self, %args) = @_;
  $self->clear_validated if $self->validated;
  foreach my $validation ($self->validations) {
    my %validation_args = (%{$validation->[1]}, %args);
    $validation->[0]($self, \%validation_args);
  }
  $self->validated(1);
  return $self;
}

1;

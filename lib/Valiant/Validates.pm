package Valiant::Validates;

use Moo::Role;
use Module::Runtime 'use_module';
use String::CamelCase 'camelize';
use Scalar::Util 'blessed';
use Valiant::Util 'throw_exception', 'debug';

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

my $named_validators;
my $attribute_valiators;

sub named_validators {
  my $class = shift;
  $class = ref($class) if ref($class);
  my $varname = "${class}::named_validators";

  no strict "refs";
  return %$varname,
    map { $_->named_validators } 
    grep { $_->can('named_validators') }
      $class->ancestors;
}

sub attribute_valiators {
  my $class = shift;
  $class = ref($class) if ref($class);
  my $varname = "${class}::attribute_valiators";

  no strict "refs";
  return %$varname,
    map { $_->attribute_valiators } 
    grep { $_->can('attribute_valiators') }
      $class->ancestors;
}

sub attribute_valiators_for {
  my ($class, $attr) = @_;
  my %validators = $class->attribute_valiators;
  return $validators{$attr} ||+{};
}

sub has_validator_for_attribute {
  my ($class, $validator_name, $attr) = @_;
  my %validators = $class->attribute_valiators;
  return @{ $validators{$attr}{$validator_name}||[] };
}

sub _push_named_validators {
  my ($class, $name, $validator) = @_;
  $class = ref($class) if ref($class);
  my $named_validators = "${class}::named_validators";
  my $attribute_valiators = "${class}::attribute_valiators";

  if(defined $validator) {
    no strict "refs";
    push @{$named_validators->{$name}}, $validator;
    foreach my $attr ( @{ $validator->attributes||[] }) {
      push @{$attribute_valiators->{$attr}{$name}}, $validator;
    }
  }
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
  return $self;
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
    my $package_to_test = $_;
    eval { use_module $package_to_test } || do {
      # This regexp matches too much... We need to add the package
      # path here just the path delim will vary from platform to platform
      my $notional_filename = Module::Runtime::module_notional_filename($package_to_test);
      if($@=~m/^Can't locate $notional_filename/) {
        debug 1, "Can't find '$package_to_test' in \@INC";
        0;
      } else {
        throw_exception UnexpectedUseModuleError => (package => $package_to_test, err => $@);
      }
    }
  }  @validator_packages;
  throw_exception('NameNotValidator', name => $key, packages => \@validator_packages)
    unless $validator_package;
  debug 1, "Found $validator_package in \@INC";
  return $validator_package;
}

sub _create_validator {
  my ($self, $validator_package, $args) = @_;
  debug 1, "Trying to create validator from $validator_package";
  my $validator = $validator_package->new($args);
  return $validator;
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
    $args->{model_class} = $self;

    my $new_validator = $self->_create_validator($validator_package, $args);
    push @validators, $new_validator;
    $self->_push_named_validators($package_part, $new_validator);
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

  my $class =  ref($self) || $self;
  my @parts = ((split '::', $class), $package);
  my @project_inc = ();
  while(@parts) {
    push @project_inc, join '::', (@parts, $class->default_validator_namepart, $package);
    pop @parts;
  }
  push @project_inc, join '::', $class->default_validator_namepart, $package; # Not sure we should allow (add flag?)
  return @project_inc;
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
    if( (ref($with)||'') eq 'CODE') {
      push @validators, [$with, \%options];
      next VALIDATOR_WITHS;
    }
    debug 1, "Trying to find a validator for '$with'";
    my @possible_packages = $self->_normalize_validator_package($with);
    foreach my $package(@possible_packages) {
      my $found_package = eval {
        use_module($package);
      } || do {
        my $notional_filename = Module::Runtime::module_notional_filename($package);
        if($@=~m/^Can't locate $notional_filename/) {
          debug 1, "Can't find '$package' in \@INC";
          0;
        } else {
          # Probably a syntax error in the code of $package
          throw_exception UnexpectedUseModuleError => (package => $package, err => $@);
        }
      };
      if($found_package) {
        debug 1, "Found '$found_package' in \@INC";
        push @validators, $package->new(%options);
        next VALIDATOR_WITHS; # Only load the first one found
      } else {
        debug 1, "Failed to find '$with' in \@INC";
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

sub inject_attribute {
  my ($class, $attribute_to_inject) = @_;
  eval "package $class; has $attribute_to_inject => (is=>'ro');";
}

1;

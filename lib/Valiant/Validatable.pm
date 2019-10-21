package Valiant::Validatable;

use Moo::Role;
use Module::Runtime;

sub error_class { 'Valiant::Errors' }

has '_errors' => (
  is => 'ro',
  required => 1,
  lazy => 1,
  init_arg => undef,
  builder => '_build_errors',
);

  sub _build_errors {
    my ($self) = @_;
    my $error_class = $self->error_class;
    return Module::Runtime::use_module($error_class)->new(object=>$self);
  }

sub errors {
  my $self = shift;
  if(my $field = shift) {
    return $self->_errors->field($field);
  } else {
    return $self->_errors;
  }
}

sub naming_class { 'Valiant::Validatable::Naming' }

has 'model_name' => (
  is => 'ro',
  required => 1,
  lazy => 1,
  init_arg => undef,
  builder => '_build_naming',
);

  sub _build_naming {
    my $self = shift;
    my $naming_class = $self->naming_class;
    return Module::Runtime::use_module($naming_class)->new(object=>$self);
  }

sub read_attribute_for_validation {
  my ($self, $attribute) = @_;
  return $self->$attribute;
}

sub human_attribute_name {
  my ($self, $attribute, $options) = @_;
  $options = +{} unless $options;
  return $attribute;
  # TODO localization
  return $self->localize($attribute, %$options);
}

sub run_validations {
  my ($self) = @_;
  foreach my $validation ($self->validations) {
    $validation->($self);
  }
}

## TODO valid, invalid

1;

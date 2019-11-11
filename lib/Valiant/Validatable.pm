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

sub i18n_class { 'Valiant::I18N' }

has 'i18n' => (
  is => 'ro',
  required => 1,
  default => sub { Module::Runtime::use_module(shift->i18n_class) },
);

  sub _build_errors {
    my ($self) = @_;
    my $error_class = $self->error_class;
    return Module::Runtime::use_module($error_class)->new(object=>$self, i18n=>$self->i18n);
  }

sub errors {
  my $self = shift;
  if(my $attribute = shift) {
    return @{ $self->_errors->messages->{$attribute}||[] };
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
  return my $value = $self->$attribute;
}

sub human_attribute_name {
  my ($self, $attribute, $options) = @_;
  return undef if $attribute eq '_base';
  $attribute =~s/_/ /g;
  $attribute = ucfirst $attribute;  
  return my $localized = $self->translate($self->i18n->make_tag($attribute), $options);
}

sub run_validations {
  my ($self) = @_;
  foreach my $validation ($self->validations) {
    $validation->($self);
  }
}

## TODO valid, invalid

sub translate {
  my ($self, $string, $options) = @_;
  return $self->i18n->translate($self->i18n->make_tag($string), %{$options||+{}});
}

1;

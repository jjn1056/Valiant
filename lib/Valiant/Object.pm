package Valiant::Object;

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
    return Module::Runtime::use_module($error_class)->new;
  }

sub errors {
  my $self = shift;
  if(my $field = shift) {
    return $self->errors->field($field);
  } else {
    return $self->errors;
  }
}

sub read_attribute_for_validation {
  my ($self, $attr) = @_;
  return $self->$attr;
}

1;

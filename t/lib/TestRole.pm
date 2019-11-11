package TestRole;

use Moo::Role;
use Valiant::Validations;

validate sub {
  my ($self) = @_;
  $self->errors->add(_base => 'Failed TestRole');
  $self->errors->add('name');
  $self->errors->add(name => bad => +{ all=>1 } );
};


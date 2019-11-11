package Retiree;

use Moo;
use Valiant::Validations;

extends 'Person';
with 'TestRole';

has 'retirement_date' => (is=>'ro');

validate sub {
  my ($self) = @_;
  $self->errors->add(_base => 'Failed Retiree');
};

;

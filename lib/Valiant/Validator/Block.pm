package Valiant::Validator::Block;

use Moo::Role;

extends 'Valiant::Validator::Each';

has do => (is=>'ro', required=>1);

sub validate_each {
  my ($self, $record, $attribute, $value) = @_;
  $self->do->($self, $record, $attribute, $value);
}

1;

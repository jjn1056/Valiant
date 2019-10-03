package Valiant::Validator::Each;

use Moo::Role;

extends 'Valiant::Validator::Each';

has with => (is=>'ro', required=>1);

sub validate_each {
  my ($self, $record, $attribute, $value) = @_;
  my $method = $record->can($self->with);
  $record->method($attribute, $value);
}

1;

package DBIx::Class::Valiant::Validates;

use Moo::Role;

with 'Valiant::Validates';

around default_validator_namespaces => sub {
  my ($orig, $self, @args) = @_;
  return 'DBIx::Class::Valiant::Validator', $self->$orig(@args);
};

1;

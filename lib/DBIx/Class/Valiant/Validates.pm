package DBIx::Class::Valiant::Validates;

use Moo::Role;
use Valiant::I18N;

with 'Valiant::Validates';

around default_validator_namespaces => sub {
  my ($orig, $self, @args) = @_;
  return 'DBIx::Class::Valiant::Validator', $self->$orig(@args);
};

around validate => sub {
  my ($orig, $self, %args) = @_;
  #$self->clear_validated;
  return $self->$orig(%args);
};

1;

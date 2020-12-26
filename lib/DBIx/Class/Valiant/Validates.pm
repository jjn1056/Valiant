package DBIx::Class::Valiant::Validates;

use Moo::Role;
use Valiant::I18N;
use Scalar::Util;

with 'Valiant::Validates';

around default_validator_namespaces => sub {
  my ($orig, $self, @args) = @_;
  return 'DBIx::Class::Valiant::Validator', $self->$orig(@args);
};

around validate => sub {
  my ($orig, $self, %args) = @_;
  # return if $args{Scalar::Util::refaddr $self}||''; # try to stop circular
  $args{Scalar::Util::refaddr $self}++;
  
  return $self->$orig(%args);
};

1;

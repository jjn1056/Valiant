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
  $self->clear_validated;
  foreach my $associated ($self->validate_associated) {
    my $related_rs = $self->related_resultset($associated);
    my $invalid = 0;
    foreach my $row ($related_rs->all) {
      $row->validate(%args);
      $invalid = 1 if $row->invalid;
    }
    if($invalid) {
      $self->errors->add($associated, _t('invalid'));
    };
  }
  return $self->$orig(%args);
};

1;

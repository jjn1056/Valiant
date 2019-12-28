package Valiant::Result;

use Moo;

with 'Valiant::Validatable';

has data => (is=>'ro', required=>1);

sub read_attribute_for_validation {
  my ($self, $attribute) = @_;
  if(ref($self->data) eq 'HASH') {
    if(defined($self->data->{$attribute})) {
      return $self->data->{$attribute};
    } else {
      die "There is no matching attribute '$attribute' in the data";
    }
  } else {
    die "Don't know what to do with ${\$self->data}";
  }
}


1;

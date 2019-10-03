package Valiant::Validator::Each;

use Moo::Role;

extends 'Valiant::Validator';
requires 'validate_each';

has allow_undef => (is=>'ro', required=>1, default=>0);
has allow_blank => (is=>'ro', required=>1, default=>0);
has attributes => (is=>'ro', required=>1);

sub validate {
  my ($self, $object) = @_;
  foreach my $attribute (@{ $self->attributes }) {
    my $value = $object->read_attribute_for_validation($attribute);
    next if $self->allow_undef && not(defined $value);
    next if $self->allow_blank && $value eq '';
    $self->validate_each($object, $attribute, $value);
  }
};

1;

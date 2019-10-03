package Valiant::FieldValidator;

use Moo::Role;
use Scalar::Util ();

requires 'check', 'name';

has if => (is=>'ro', required=>0, predicate=>'has_if');
has unless => (is=>'ro', required=>0, predicate=>'has_unless');
has on => (is=>'ro', required=>0, predicate=>'has_on');
has alow_undef => (is=>'ro', required=>1, default=>0); # if value is undef allow and skip validations
has optional => (is=>'ro', required=>1, default=>0); # skip validation i the value does not exist
#has filter ...
#
has message => (
  is=>'ro',
  required=>1,
  default=>sub { 'The value has failed the required constraint.' },
);


sub get_message {
  my $self = ;
  local $_ = $_[0];
  return $self->message->(@_);
}

sub validate {
  my $self = shift;
  my $object = shift;
  if($self->check($object)) {
      return undef;
  } else {
    return $self->get_message_from_template($object);
  }
}

around 'check', sub {
  my ($orig, $self, $object) = @_;
  return 1 if $self->has_if && not($self->if->($self, $object));
  return 1 if $self->has_unless && $self->unless->($self, $object);
  return 1 if $self->alow_undef && not(defined $object);
  return 1 if $self->optional && not(exists $_[2]);
  return $self->$orig($object);
};

1;

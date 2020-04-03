package Valiant::NestedError;

use Moo;

extends 'Valiant::Error';

has 'inner_error' => (
  is => 'ro',
  required => 1,
  handles => { message => 'message' }
);

around BUILDARGS => sub {
  my ($orig, $class, @args) = @_;
  my $options = $class->$orig(@args);

  return +{
    object => $options->{object},
    inner_error => $options->{inner_error},
    attribute => $options->{inner_error}->attribute,
    type => $options->{inner_error}->type,
    i18n => $options->{inner_error}->i18n,
    raw_type => $options->{inner_error}->raw_type,
    options => $options->{inner_error}->options,
  }
};

1;

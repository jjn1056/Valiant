package Valiant::Validator::With;

use Moo;

with 'Valiant::Validator::Each';

has cb => (is=>'ro', predicate=>'has_cb');
has method => (is=>'ro', predicate=>'has_method');

around BUILDARGS => sub {
  my ( $orig, $class, @args ) = @_;
  return +{ cb => $args[0], attributes => $args[1] } if ref($args[0]) eq 'CODE';
  #return +{ method => $args[0], attributes => $args[1] } if ref($args[0]) eq 'CODE';
  return $class->$orig(@args);
};

sub BUILD {
  my ($self, $args) = @_;
  $self->_requires_one_of($args, 'cb', 'method');
}

sub validate_each {
  my ($self, $record, $attribute, $value) = @_;
  $self->cb->($record, $attribute, $value, $self->options) if $self->has_cb;
  if($self->has_method) {
    if(my $method_cb = $record->can($self->method)) {
      $method_cb->($record, $attribute, $value, $self->options);
    } else {
      die ref($record) ." has no method '${\$self->method}'";
    }
  }
}

1;

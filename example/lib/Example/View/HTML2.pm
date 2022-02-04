package Example::View::HTML2;

use Moose;
use Valiant::HTML::Form ();

use Mojo::ByteStream qw(b);
use Scalar::Util 'blessed';

extends 'Catalyst::View::MojoTemplate';

__PACKAGE__->config(
  helpers => {
    form_for => \&form_for,
    fields_for => \&fields_for,
  },
);

sub form_for {
  my ($self, $c, @args) = @_;
  return b Valiant::HTML::Form::form_for(@args);
}

sub fields_for {
  my ($self, $c, @args) = @_;
  return b Valiant::HTML::Form::fields_for(@args);
}


    
__PACKAGE__->meta->make_immutable;

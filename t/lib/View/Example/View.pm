package View::Example::View;

use Moo;
use Catalyst::View::Valiant
  -tags => qw(div);

sub stuff2 {
  my $self = shift;
  return $self->tags->div('stuff2')
}

sub stuff3 :Renders { div 'stuff3' }

1;
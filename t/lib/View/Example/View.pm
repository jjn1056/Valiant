package View::Example::View;

use Moo;
use Catalyst::View::Valiant
  -tags => qw(div label_tag);

sub stuff2 {
  my $self = shift;
  $self->label_tag('test', sub {
    warn 'sssss'. ref shift;

  });
  return $self->tags->div('stuff2');
}

sub stuff3 :Renders {
  div 'stuff3', 
  shift->div('stuff333')
}

1;
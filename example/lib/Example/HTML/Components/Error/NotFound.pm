package Example::HTML::Components::Error::NotFound;

use Moo;
use Example::HTML::Components 'Layout';
use Valiant::HTML::TagBuilder 'div', 'h1', 'p';
use Example::Syntax;

with 'Valiant::HTML::Component';

has 'ctx' => (is=>'ro', required=>1);
has 'code' => (is=>'ro', required=>1);
has 'message' => (is=>'ro', required=>1);
has 'title' => (is=>'ro', required=>1);
has 'uri' => (is=>'ro', required=>1);

sub render($self) {
  Layout $self->title,
    div {class=>'cover'}, [
      h1 "@{[ $self->code ]}: @{[ $self->title ]}",
      p {class=>'lead'}, $self->message,
    ];
}

1;

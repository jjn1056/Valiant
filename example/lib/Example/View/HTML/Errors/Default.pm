package Example::View::HTML::Errors::Default;

use Moo;
use Example::Syntax;
use Example::View::HTML
  -tags => qw(div h1 p),
  -views => 'HTML::Layout';

has 'status_code' => (is=>'ro', required=>1);
has 'message' => (is=>'ro', required=>1);
has 'title' => (is=>'ro', required=>1);
has 'uri' => (is=>'ro', required=>1);

sub render($self, $c) {
  html_layout page_title=>$self->title, sub($layout) {
    div {class=>'cover'}, [
      h1 "@{[ $self->status_code ]}: @{[ $self->title ]}",
      p {class=>'lead'}, $self->message,
    ];
  };
}

1;

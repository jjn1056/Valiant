package Example::View::HTML::Home;

use Moo;
use Example::Syntax;
use Example::View::HTML
  -tags => qw(div blockquote),
  -views => 'HTML::Layout', 'HTML::Navbar';

has info => (is=>'rw', predicate=>'has_info');

sub render($self, $c) {
  html_layout page_title => 'Sign In', sub($layout) {
    html_navbar active_link=>'/',
    blockquote +{ if=>$self->has_info, 
      class=>"alert alert-primary", 
      role=>"alert" }, $self->info,
    div 'Welcome to your Example application Homepage';
  };
}

1;

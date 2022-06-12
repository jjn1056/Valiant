package Example::HTML::Components::Home;

use Moo;
use Example::HTML::Components 'Layout', 'Navbar';
use Valiant::HTML::TagBuilder 'div', 'blockquote', 'cond';
use Example::Syntax;

with 'Valiant::HTML::Component';

has info => (is=>'rw', predicate=>'has_info');

sub render($self) {
  Layout 'Homepage',
    Navbar +{ active_link=>'/' },
    cond { $self->has_info } sub {
      blockquote +{ class=>"alert alert-primary", role=>"alert" }, $self->info,
    },
    div 'Welcome to your Example application Homepage', 
}

1;

package Example::HTML::Components::Home;

use Moo;
use Example::HTML::Components 'Layout', 'Navbar';
use Valiant::HTML::TagBuilder 'div';
use Example::Syntax;

with 'Valiant::HTML::Component';

sub render($self) {
  return  Layout 'Homepage',
    Navbar +{ active_link=>'/' },
    div 'Welcome to your Example application Homepage', 
}

1;

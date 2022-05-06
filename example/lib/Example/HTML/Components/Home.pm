package Example::HTML::Components::Home;

use Moo;
use Example::HTML::Components 'Layout';
use Valiant::HTML::TagBuilder 'p', 'a';
use Example::Syntax;

with 'Valiant::HTML::Component';

sub render($self) {
  return  Layout 'Homepage',
    p [
      a +{href=>'/profile'}, 'Profile',
      ' or ',
      a +{href=>'/logout'}, 'Logout',
    ];
}

1;

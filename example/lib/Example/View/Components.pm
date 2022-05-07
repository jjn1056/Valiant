package Example::View::Components;

use Moose;
use Example::Syntax;

extends 'Catalyst::View::Valiant::HTML::Components';

__PACKAGE__->config(
  injected_args => +{
    FormFor => sub($self, $c) {
      return (
        csrf_token => $c->csrf_token, 
      );
    },
  },
);

__PACKAGE__->meta->make_immutable;

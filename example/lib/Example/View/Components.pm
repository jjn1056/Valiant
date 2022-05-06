package Example::View::Components;

use Moose;
use Example::Syntax;

extends 'Catalyst::View::Valiant::HTML::Components';

__PACKAGE__->config(
  injected_args => +{
    Hello => sub($self, $c) {
      return (
        wow => 'wow', 
      );
    },
  },
);

__PACKAGE__->meta->make_immutable;

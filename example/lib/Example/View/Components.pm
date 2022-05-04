package Example::View::Components;

use Moose;
use Module::Runtime;

extends 'Catalyst::View::Valiant::HTML::Components';

__PACKAGE__->config(
  injected_args => +{
    Hello => sub {
      my ($self, $c) = shift;
      return (
        wow => 'wow', 
      );
    },
  },
);

__PACKAGE__->meta->make_immutable;

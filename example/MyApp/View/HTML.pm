package MyApp::View::HTML;

use Moose;
extends 'Catalyst::View::Xslate';

__PACKAGE__->config(
  syntax => "Metakolon",
  function => {
    echo => sub {
      my @args = @_;
      return join ', ', @args;
    },
  },
);

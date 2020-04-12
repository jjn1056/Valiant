package Example::View::HTML;

use Moose;
extends 'Catalyst::View::TT';

__PACKAGE__->config(
  TEMPLATE_EXTENSION => '.html',
  WRAPPER => 'wrapper.html',
  render_die => 1,
);

1;

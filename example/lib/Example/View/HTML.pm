package Example::View::HTML;

use Moose;
use Valiant::HTML::SafeString 'concat';
use Example::Syntax;

extends 'Catalyst::View::BasePerRequest';

sub flatten_rendered($self, @rendered) {
  return concat @rendered;
}

sub link($self, @args) {
  return $self->ctx->uri(@args);
}

__PACKAGE__->config(
  content_type=>'text/html',
);

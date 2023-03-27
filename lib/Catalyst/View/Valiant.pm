package Catalyst::View::Valiant;

use Moose;
use Valiant::HTML::SafeString 'safe_concat';
use Example::Syntax;

extends 'Catalyst::View::BasePerRequest';

sub flatten_rendered($self, @rendered) {
  return safe_concat @rendered;
}

sub link($self, @args) {
  return $self->ctx->uri(@args);
}

__PACKAGE__->config(
  content_type=>'text/html',
);

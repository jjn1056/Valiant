package Example::View::HTML;

use Moose;
use Valiant::HTML::SafeString 'concat';
use Example::Syntax;

extends 'Catalyst::View::BasePerRequest';

sub flatten_rendered_for_response_body($self, @rendered) {
  return concat grep { defined($_) } @rendered;
}

__PACKAGE__->config(
  content_type=>'text/html',
);

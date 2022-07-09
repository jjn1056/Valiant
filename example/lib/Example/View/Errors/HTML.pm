package Example::View::Errors::HTML;

use Moose;
use Example::Syntax;

extends 'Catalyst::View::Errors::HTML';

sub http_404($self, $c, %args) {
  my $lang = $self->get_language($c);
  my $message_info = $self->finalize_message_info($c, 404, $lang, %args);
  $c->view('Components::Error::NotFound', %$message_info);
}

__PACKAGE__->meta->make_immutable;


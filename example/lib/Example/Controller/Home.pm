package Example::Controller::Home;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

sub root :Chained(/auth) PathPart('') Args(0) Name(home) Verbs(GET) ($self, $c, $user) {
  $c->view('HTML::Home');
}

  sub GET :Action ($self, $c) {
    $c->view->info('The time is '. localtime);
    return $c->view->set_http_ok;
  }

__PACKAGE__->meta->make_immutable;

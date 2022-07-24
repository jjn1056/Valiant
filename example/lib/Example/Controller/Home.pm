package Example::Controller::Home;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

sub root :Chained(/auth) PathPart('') Args(0) Name(home) Does(Verbs) View(HTML::Home)  ($self, $c) { }

  sub GET :Action ($self, $c) {
    $c->view->info('The time is '. localtime);
    return $c->res->code(200);
  }

__PACKAGE__->meta->make_immutable;

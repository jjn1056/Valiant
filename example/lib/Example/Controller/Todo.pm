package Example::Controller::Todo;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::ControllerPerRequest';

sub root :Chained(/auth) PathPart('todos') Args(1) Does(Verbs) ($self, $c, $id) {
  my $todo = $c->user->todos->find($id) || return $c->detach_error(404);
  my $view = $c->view('Components::Todo', todo => $todo);
  return $todo, $view;
}

  sub GET :Action ($self, $c, $todo, $view) { return $view->http_ok }

  sub PATCH :Action ($self, $c, $todo, $view) {
    my %params = $c->structured_body(
      ['todo'], 'title', 'status'
    )->to_hash;

    $todo->set_columns_recursively(\%params)->update;

    return $todo->valid ?
      $c->redirect_to_action('/todos/root')  :
        $view->http_bad_request;
  }

__PACKAGE__->meta->make_immutable;


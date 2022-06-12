package Example::Controller::Todo;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::ControllerPerRequest';

has todo => (is=>'rw');

sub root :Chained(/auth) PathPart('todos') Args(1) Does(Verbs) View(Components::Todo) ($self, $c, $id) {
  $self->todo($c->user->todos->find($id) || return $c->detach_error(404));
}

  sub GET :Action ($self, $c) { return $c->res->code(200) }

  sub PATCH :Action RequestModel(TodoRequest) ($self, $c, $request) {
    $self->todo->set_from_request($request);
    return $self->todo->valid ?
      $c->redirect_to_action('/todos/root') :
        $c->res->code(400);
  }

__PACKAGE__->meta->make_immutable;


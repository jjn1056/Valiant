package Example::Controller::Todos;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

has todo => (is=>'rw');

sub root :Chained(/auth) PathPart('todos') Args(0) Verbs(GET,POST) RequestModel(TodosQuery) ($self, $c, $q) {
  my ($list, $pager) = $c->user->request_todos($q);
  $c->view('HTML::Todos',
    todo => my $todo = $c->user->new_todo,
    list => $list,
    pager => $pager,
    status => $q->status,
  );
  $self->todo($todo);
}

  sub GET :Action ($self, $c) { return $c->view->set_http_ok }

  sub POST :Action RequestModel(TodoRequest) ($self, $c, $request) {
    $self->todo->set_from_request($request);
    return $self->todo->valid ?
      $c->redirect_to_action('root') :
        $c->view->set_http_bad_request;
  }

__PACKAGE__->meta->make_immutable;

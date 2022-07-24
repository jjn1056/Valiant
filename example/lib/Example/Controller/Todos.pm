package Example::Controller::Todos;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

has 'query' => (is=>'rw');

has 'list' => (
  is=>'ro',
  required=>1,
  lazy=>1, default=>sub($self) { $self->ctx->user->request_todos($self->query) }
);

has todo => (
  is=>'ro',
  required=>1,
  lazy=>1,
  default=>sub($self) { $self->ctx->user->new_todo },
);

sub root :Chained(/auth) PathPart('todos') Args(0) Does(Verbs) View(HTML::Todos) RequestModel(TodosQuery) ($self, $c, $q) {
  $self->query($q);
}

  sub GET :Action ($self, $c) { return $c->res->code(200) }

  sub POST :Action RequestModel(TodoRequest) ($self, $c, $request) {
    $self->todo->set_from_request($request);
    return $self->todo->valid ?
      $c->redirect_to_action('root') :
        $c->res->code(400);
  }

__PACKAGE__->meta->make_immutable;


package Example::Controller::Todos;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

sub todos :Chained(*Secured) CaptureArgs(0) Name(TodosRoot) ($self, $c, $user) {
  my $collection = $user->todos;
  $c->action->next($collection);
}

  sub list :GET Chained(todos) PathPart('') Args(0) QueryModel(TodosQuery) Name(TodosList) ($self, $c, $collection, $todo_query) {
    my $sessioned_query = $c->model('TodosQuery::Session', $todo_query);
    my $list = $collection->filter_by_request($sessioned_query);
    $c->view('HTML::Todos',
      list => $list,
      todo => $list->new_todo,
    );
  }

  sub create :POST Chained(todos) PathPart('') Args(0) RequestModel(TodoRequest) ($self, $c, $collection, $request) {
    my $todo = $collection->create_from_request($request);
    return $todo->valid ?
      $c->redirect_to_action('*TodoEdit', [$todo->id]) :
        $c->view->set_http_bad_request;
  }

__PACKAGE__->meta->make_immutable;

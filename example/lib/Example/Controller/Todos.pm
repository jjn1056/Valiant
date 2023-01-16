package Example::Controller::Todos;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

sub root :Chained(*Secured) PathPart('todos') CaptureArgs(0) ($self, $c, $user) {
  my $collection = $user->todos;
  $c->action->next($collection);
}

  sub setup :Chained(root) PathPart('') CaptureArgs(0) QueryModel(TodosQuery) ($self, $c, $collection, $todo_query) {
    my $sessioned_query = $c->model('TodosQuery::Session', $todo_query);
    my $list = $collection->filter_by_request($sessioned_query);
    $c->view('HTML::Todos',
      list => $list,
      todo => my $todo = $list->new_todo,
    );
    $c->action->next($todo);
  }

    sub list :GET Chained(setup) PathPart('') Args(0) Name(TodosList) ($self, $c, $todo) {
      return $c->view->set_http_ok;  
    }

    sub create :POST Chained(setup) PathPart('') Args(0) RequestModel(TodoRequest) ($self, $c, $todo, $request) {
      $todo->set_from_request($request); 
      return $todo->valid ?
        $c->redirect_to_action('*TodoEdit', [$todo->id]) :
          $c->view->set_http_bad_request;
    }

__PACKAGE__->meta->make_immutable;

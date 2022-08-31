package Example::Controller::Todos;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

sub setup_collection :Chained(/auth) PathPart('todos') CaptureArgs(0) ($self, $c, $user) {
  my $collection = $user->todos;
  $c->next_action($collection);
}

  sub prepare_collection_response :Chained(setup_collection) PathPart('') Args(0) Verbs(GET,POST) RequestModel(TodosQuery) Name(TodosResponse) ($self, $c, $q, $collection) {
    my $sessioned_query = $c->model('TodosQuery::Session', $q);
    $c->view('HTML::Todos',
      todo => my $todo = $c->user->new_todo,
      list => $collection->filter_by_request($sessioned_query),
    );
    $c->next_action($todo);
  }

    sub POST :Action RequestModel(TodoRequest) ($self, $c, $request, $todo) {
      $todo->set_from_request($request);
      return $todo->valid ?
        $c->redirect_to_action('#TodoResponse', [$todo->id]) :
          $c->view->set_http_bad_request;
    }

__PACKAGE__->meta->make_immutable;

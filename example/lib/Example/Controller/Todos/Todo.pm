package Example::Controller::Todos::Todo;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

sub root :Chained(../root) PathPart('') CaptureArgs(1) ($self, $c, $collection, $id) {
  my $todo = $collection->find($id) || return $c->detach_error(404, +{error=>"Todo id $id not found"});
  $c->action->next($todo);
}

  sub setup :Chained(root) PathPart('') CaptureArgs(0) ($self, $c, $todo) {
    $c->view('HTML::Todo', todo => $todo);
    $c->action->next($todo);
  }

    sub edit :PATCH Chained(setup) PathPart('') RequestModel(TodoRequest) Args(0) ($self, $c, $todo, $request) {
      $todo->set_from_request($request);
      return $todo->valid ?
        $c->detach('view') :
          $c->view->set_http_bad_request
    }

    sub view :GET Chained(setup) PathPart('') Args(0) Name(TodoEdit) ($self, $c, $todo) {
        return $c->view->set_http_ok;
    }

__PACKAGE__->meta->make_immutable;

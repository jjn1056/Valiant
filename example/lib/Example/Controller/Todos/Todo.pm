package Example::Controller::Todos::Todo;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

sub root :Chained(*TodosRoot) PathPart('') CaptureArgs(1) ($self, $c, $collection, $id) {
  my $todo = $collection->find($id) || return $c->detach_error(404, +{error=>"Todo id $id not found"});
  $c->action->next($todo);
}

    sub edit :PATCH Chained(root) PathPart('') RequestModel(TodoRequest) Args(0) ($self, $c, $todo, $request) {
      $todo->set_from_request($request);
      return $todo->valid ?
        $c->redirect_to_action('*TodosList') :
          $c->view->set_http_bad_request
    }

    sub view :GET Chained(root) PathPart('') Args(0) Name(TodoEdit) ($self, $c, $todo) {
        return $c->view('HTML::Todo', todo=>$todo)->set_http_ok;
    }

__PACKAGE__->meta->make_immutable;

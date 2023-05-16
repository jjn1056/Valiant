package Example::Controller::Todos;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;
use Types::Standard qw(Int);

extends 'Example::Controller';

# /todos/...
sub root :Via('../protected') At('todos/...') ($self, $c, $user) {
  $c->action->next(my $collection = $user->todos);
}

  # /todos/...
  sub search :Via('root') At('/...') QueryModel ($self, $c, $collection, $todo_query) {
    my $sessioned_query = $c->model('Todos::Session', $todo_query);
    $collection = $collection->filter_by_request($sessioned_query);
    $c->action->next($collection);
  }

    # GET /todos
    sub list :GET Via('search') At('') ($self, $c, $collection) {
      return $self->view(
        list => $collection,
        todo => $collection->new_todo,
      )->set_http_ok;
    }

  # /todos/...
  sub prepare_build :Via('search') At('/...') ($self, $c, $collection) {
    $self->view_for('list',
      list => $collection,
      todo => my $new_todo = $collection->new_todo
    );
    $c->action->next($new_todo);
  }

    # GET /todos/new
    sub build :GET Via('prepare_build') At('new') ($self, $c, $new_todo) {
      return $c->view->set_http_ok;
    }

    # POST /todos/
    sub create :POST Via('prepare_build') At('') BodyModel ($self, $c, $new_todo, $r) {
      $new_todo->set_from_request($r);
      return $new_todo->set_from_request($r) ?
        $c->view->clear_todo && $c->view->set_http_ok :
          $c->view->set_http_bad_request;
    }

  # /todos/{:Int}/...
  sub find :Via('root') At('{:Int}/...') ($self, $c, $collection, $id) {
    my $todo = $collection->find($id) // $c->detach_error(404, +{error=>"Todo id $id not found"});
    $c->action->next($todo);
  }

    # /todos/{:Int}/...
    sub prepare_edit :Via('find') At('/...') ($self, $c, $todo) {
      $self->view_for('edit', todo => $todo);
      $c->action->next($todo);
    }

      # GET /todos/{:Int}/edit
      sub edit :GET Via('prepare_edit') At('edit') ($self, $c, $todo) {
        return $c->view->set_http_ok;
      }
    
      # PATCH /todos/{:Int}
      sub update :PATCH Via('prepare_edit') At('') BodyModelFor('create') ($self, $c, $todo, $r) {
        return $todo->set_from_request($r) ?
          $c->view->set_http_ok :
            $c->view->set_http_bad_request;
      }

__PACKAGE__->meta->make_immutable;
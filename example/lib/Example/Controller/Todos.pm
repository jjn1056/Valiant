package Example::Controller::Todos;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;
use Types::Standard qw(Int);

extends 'Example::Controller';

# /todos/...
sub root :At('$path_end/...') Via('../protected') ($self, $c, $user) {
  $c->action->next(my $collection = $user->todos);
}

  # /todos/...
  sub search :At('/...') Via('root') QueryModel ($self, $c, $collection, $todo_query) {
    my $sessioned_query = $c->model('Todos::Session', $todo_query);
    $collection = $collection->filter_by_request($sessioned_query);
    $c->action->next($collection);
  }

    # GET /todos
    sub list :Get('') Via('search') ($self, $c, $collection) {
      return $self->view(
        list => $collection,
        todo => $collection->new_todo,
      )->set_http_ok;
    }

  # /todos/...
  sub prepare_build :At('/...') Via('search') ($self, $c, $collection) {
    $self->view_for('list',
      list => $collection,
      todo => my $new_todo = $collection->new_todo
    );
    $c->action->next($new_todo);
  }

    # GET /todos/new
    sub build :Get('new') Via('prepare_build') ($self, $c, $new_todo) {
      return $c->view->set_http_ok;
    }

    # POST /todos/
    sub create :Post('') Via('prepare_build') BodyModel ($self, $c, $new_todo, $bm) {
      return $new_todo->set_from_request($bm) ?
        $c->view->clear_todo && $c->view->set_http_ok :
          $c->view->set_http_bad_request;
    }

  # /todos/{:Int}/...
  sub find :At('{:Int}/...') Via('root') ($self, $c, $collection, $id) {
    my $todo = $collection->find($id) // $c->detach_error(404, +{error=>"Todo id $id not found"});
    $c->action->next($todo);
  }

    # /todos/{:Int}/...
    sub prepare_edit :At('/...') Via('find') ($self, $c, $todo) {
      $self->view_for('edit', todo => $todo);
      $c->action->next($todo);
    }

      # GET /todos/{:Int}/edit
      sub edit :Get('edit') Via('prepare_edit') ($self, $c, $todo) {
        return $c->view->set_http_ok;
      }
    
      # PATCH /todos/{:Int}
      sub update :Patch('') Via('prepare_edit') BodyModelFor('create') ($self, $c, $todo, $bm) {
        return $todo->set_from_request($bm) ?
          $c->view->set_http_ok :
            $c->view->set_http_bad_request;
      }

__PACKAGE__->meta->make_immutable;

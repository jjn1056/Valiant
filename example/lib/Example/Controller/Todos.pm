package Example::Controller::Todos;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;
use Types::Standard qw(Int);

extends 'Example::Controller';

# /todos/...
sub collection :Via('*Private') At('todos/...') ($self, $c, $user) {
  $c->action->next(my $collection = $user->todos);
}

  # /todos/...
  sub setup_list :Via('collection') At('/...') QueryModel(TodosQuery) ($self, $c, $collection, $todo_query) {
    my $sessioned_query = $c->model('TodosQuery::Session', $todo_query);
    my $list = $collection->filter_by_request($sessioned_query);
    $c->action->next($list);
  }

    # GET /todos
    sub list :GET Via('setup_list') At('') ($self, $c, $list) {
      return $c->view('HTML::Todos',
        list => $list,
        todo => my $new_todo = $list->new_todo,
      )->set_http_ok;
    }

  # /todos/...
  sub setup_new :Via('setup_list') At('/...') ($self, $c, $list) {
    $c->view('HTML::Todos',
      list => $list,
      todo => my $new_todo = $list->new_todo,
    );
    $c->action->next($new_todo);
  }

    # POST /todos/
    sub create :POST Via('setup_new') At('') BodyModel(TodoRequest) ($self, $c, $new_todo, $r) {
      return $new_todo->set_from_request($r) ?
        $c->redirect_to_action('list') :  # Redirect because if no error we want a clean form
          $c->view->set_http_bad_request;
    }

  # /todos/{:Int}/...
  sub entity :Via('collection') At('{:Int}/...') ($self, $c, $collection, $id) {
    my $todo = $collection->find($id) // $c->detach_error(404, +{error=>"Todo id $id not found"});
    $c->action->next($todo);
  }

    # /todos/{:Int}/...
    sub setup_update :Via('entity') At('/...') ($self, $c, $todo) {
      $c->view('HTML::Todos::EditTodo', todo => $todo);
      $c->action->next($todo);
    }

      # GET /todos/{:Int}/edit
      sub edit :GET Via('setup_update') At('edit') ($self, $c, $todo) {
        return $c->view->set_http_ok;
      }
    
      # PATCH /todos/{:Int}
      sub update :PATCH Via('setup_update') At('') BodyModel(TodoRequest) ($self, $c, $todo, $r) {
        return $todo->set_from_request($r) ?
          $c->view->set_http_ok :
            $c->view->set_http_bad_request;
      }



__PACKAGE__->meta->make_immutable;

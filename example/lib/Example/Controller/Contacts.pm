package Example::Controller::Contacts;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;
use Types::Standard qw(Int);

extends 'Example::Controller';

# Example of a classic full CRUDL controller

# /contacts/...
sub root :Via('../protected') At('contacts/...') ($self, $c, $user) {
  $c->action->next(my $collection = $user->contacts);
}

  # /contacts/...
  sub search :Via('root') At('/...') QueryModel ($self, $c, $collection, $todo_query) {
    my $sessioned_query = $c->model('Contacts::Session', $todo_query);
    $collection = $collection->filter_by_request($sessioned_query);
    $c->action->next($collection);
  }

    # GET /contacts
    sub list :GET Via('search') At('') ($self, $c, $collection) {
      return $self->view(list => $collection)->set_http_ok;
    }

  # /contacts/...
  sub prepare_build :Via('root') At('/...') ($self, $c, $collection) {
    $self->view_for('build', contact => my $new_contact = $collection->new_contact);
    $c->action->next($new_contact);
  }

    # GET /contacts/new
    sub build :GET Via('prepare_build') At('/new') ($self, $c, $new_contact) {
      return $c->view->set_http_ok;
    }

    # POST /contacts/
    sub create :POST Via('prepare_build') At('') BodyModel ($self, $c, $new_contact, $r) {
      return $new_contact->set_from_request($r) ?
        $c->view->set_http_ok : 
          $c->view->set_http_bad_request;
    }

  # /contacts/{:Int}/...
  sub find :Via('root') At('{:Int}/...') ($self, $c, $collection, $id) {
    my $contact = $collection->find($id) // $c->detach_error(404, +{error=>"Contact id $id not found"});
    $c->action->next($contact);
  }

    # GET /contacts/{:Int}
    sub show :GET Via('find') At('') ($self, $c, $contact) {
      # This is just a placeholder for how I'd add a route to handle
      # showing a non editable webpage for the found entity
    }

    # DELETE /contacts/{:Int}
    sub delete :DELETE Via('find') At('') ($self, $c, $contact) {
      return $contact->delete && $c->redirect_to_action('list');
    }

    # /contacts/{:Int}/...
    sub prepare_edit :Via('find') At('/...') ($self, $c, $contact) {
      $self->view_for('edit', contact => $contact);
      $c->action->next($contact);
    }

      # GET /contacts/{:Int}/edit
      sub edit :GET Via('prepare_edit') At('edit') ($self, $c, $contact) {
        return $c->view->set_http_ok;
      }
    
      # PATCH /contacts/{:Int}
      sub update :PATCH Via('prepare_edit') At('') BodyModelFor('create') ($self, $c, $contact, $r) {
        return $contact->set_from_request($r) ?
          $c->view->set_http_ok :
            $c->view->set_http_bad_request;
      }

__PACKAGE__->meta->make_immutable;

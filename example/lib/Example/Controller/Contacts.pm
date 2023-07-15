package Example::Controller::Contacts;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;
use Types::Standard qw(Int);

extends 'Example::Controller';

# Example of a classic full CRUDL controller

# /contacts/...
sub root :At('$path_end/...') Via('../protected')  ($self, $c, $user) {
  $c->action->next(my $collection = $user->contacts);
}

  # /contacts/...
  sub search :At('/...') Via('root') QueryModel ($self, $c, $collection, $query) {
    my $sessioned_query = $c->model('Contacts::Session', $query);
    $collection = $collection->filter_by_request($sessioned_query);
    $c->action->next($collection);
  }

    # GET /contacts
    sub list :Get('') Via('search') ($self, $c, $collection) {
      return $self->view(list => $collection)->set_http_ok;
    }

  # /contacts/...
  sub prepare_build :At('/...') Via('root') ($self, $c, $collection) {
    $self->view_for('build', contact => my $new_contact = $collection->new_contact);
    $c->action->next($new_contact);
  }

    # GET /contacts/new
    sub build :Get('/new') Via('prepare_build') ($self, $c, $new_contact) {
      return $c->view->set_http_ok;
    }

    # POST /contacts/
    sub create :Post('') Via('prepare_build') BodyModel ($self, $c, $new_contact, $bm) {
      return $new_contact->set_from_request($bm) ?
        $c->view->set_http_ok : 
          $c->view->set_http_bad_request;
    }

  # /contacts/{:Int}/...
  sub find :At('{:Int}/...') Via('root')  ($self, $c, $collection, $id) {
    my $contact = $collection->find($id) // $c->detach_error(404, +{error=>"Contact id $id not found"});
    $c->action->next($contact);
  }

    # GET /contacts/{:Int}
    sub show :Get('') Via('find') ($self, $c, $contact) {
      # This is just a placeholder for how I'd add a route to handle
      # showing a non editable webpage for the found entity
    }

    # DELETE /contacts/{:Int}
    sub delete :Delete('') Via('find') ($self, $c, $contact) {
      return $contact->delete && $c->redirect_to_action('list');
    }

    # /contacts/{:Int}/...
    sub prepare_edit :At('/...') Via('find') ($self, $c, $contact) {
      $self->view_for('edit', contact => $contact);
      $c->action->next($contact);
    }

      # GET /contacts/{:Int}/edit
      sub edit :Get('edit') Via('prepare_edit') ($self, $c, $contact) {
        return $c->view->set_http_ok;
      }
    
      # PATCH /contacts/{:Int}
      sub update :Patch('') Via('prepare_edit') BodyModelFor('create') ($self, $c, $contact, $bm) {
        return $contact->set_from_request($bm) ?
          $c->view->set_http_ok :
            $c->view->set_http_bad_request;
      }

__PACKAGE__->meta->make_immutable;

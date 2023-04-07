package Example::Controller::Contacts;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;
use Types::Standard qw(Int);

extends 'Example::Controller';

# Example of a classic full CRUDL controller

  # /contacts/...
sub root :Via(*Secured) At('contacts/...') ($self, $c, $user) {
  $c->action->next(my $contacts = $user->contacts);
}

  # GET /contacts
  sub list :GET Via(root) At('') QueryModel(ContactsQuery) ($self, $c, $contacts, $contacts_query) {
    my $sessioned_query = $c->model('ContactsQuery::Session', $contacts_query);
    my $list = $contacts->filter_by_request($sessioned_query);
    return $c->view('HTML::Contacts', list => $list)->set_http_ok;
  }

  # /contacts/new/...
  sub root_new :Via(root) At('new/...') ($self, $c, $collection) {
    my $new_contact = $collection->new_contact;
    $c->view('HTML::Contacts::Contact', contact => $new_contact );
    $c->action->next($new_contact);
  }

    # GET /contacts/new
    sub show_new :GET Via(root_new) At('') ($self, $c, $new_contact) {
      return $c->view->set_http_ok;
    }

    # POST /contacts/new
    sub create :POST Via(root_new) At('') RequestModel(ContactRequest) ($self, $c, $new_contact, $r) {
      return $new_contact->set_from_request($r) ?
        $c->view->set_http_ok : 
          $c->view->set_http_bad_request;
    }

  # /contacts/{:Int}/...
  sub root_edit :Via(root) At('{:Int}/...') ($self, $c, $collection, $id) {
    my $contact = $collection->find($id) // $c->detach_error(404, +{error=>"Contact id $id not found"});
    $c->view('HTML::Contacts::Contact', contact => $contact);
    $c->action->next($contact);
  }

    # GET /contacts/{:Int}
    sub show_edit :GET Via(root_edit) At('') ($self, $c, $contact) {
      return $c->view->set_http_ok;
    }
  
    # PATCH /contacts/{:Int}
    sub edit :PATCH Via(root_edit) At('') RequestModel(ContactRequest) ($self, $c, $contact, $r) {
      return $contact->set_from_request($r) ?
        $c->view->set_http_ok :
          $c->view->set_http_bad_request;
    }

    # DELETE /contacts/{:Int}
    sub delete :DELETE Via(root_edit) At('') ($self, $c, $contact) {
      return $contact->delete && $c->redirect_to_action('list');
    }

__PACKAGE__->meta->make_immutable;

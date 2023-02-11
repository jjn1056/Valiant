package Example::Controller::Contacts::Contact;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

sub root :Chained(../root) PathPart('') CaptureArgs(0) ($self, $c, $collection) {
  $c->action->next($collection);
}

  sub setup_new :Chained(root) PathPart(new) CaptureArgs(0) ($self, $c, $collection) {
    $c->view('HTML::Contact', contact => my $new_contact = $collection->new_contact);
    $c->action->next($new_contact);
  }

    sub show_new :GET Chained(setup_new) PathPart('') Args(0) ($self, $c, $new_contact) {
      $c->view->set_http_ok;
    }

    sub create :POST Chained(setup_new) PathPart('') Args(0) RequestModel(ContactRequest) ($self, $c, $new_contact, $r) {
      return $new_contact->set_from_request($r) ?
        $c->redirect_to_action($self->action_for('edit'), [$new_contact->id]) : 
          $c->view->set_http_bad_request;
    }

  sub setup_edit :Chained(root) PathPart('') CaptureArgs(1) ($self, $c, $collection, $id) {
    my $contact = $collection->find($id) // $c->detach_error(404, +{error=>"Contact id $id not found"});
    $c->view('HTML::Contact', contact => $contact);
    $c->action->next($contact);
  }

    sub show_edit :GET Chained(setup_edit) PathPart('') Args(0) ($self, $c, $contact) {
      $c->view->set_http_ok;
    }
  
    sub edit :PATCH Chained(setup_edit) PathPart('') RequestModel(ContactRequest) Args(0) ($self, $c, $contact, $r) {
      return $contact->set_from_request($r) ?
        $c->view->set_http_ok :
          $c->view->set_http_bad_request;
    }

    sub delete_contact :DELETE Chained(setup_edit) PathPart('') Args(0) ($self, $c, $contact) {
      return $contact->delete && $c->redirect_to_action('../list');
    }

__PACKAGE__->meta->make_immutable;

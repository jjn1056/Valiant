package Example::Controller::Contacts::Contact;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

sub create :Chained(../setup) PathPart(new) Args(0) Verbs(GET,POST) ($self, $c, $collection) {
  my $contact = $collection->new_contact;
  $c->view('HTML::Contact', contact => $contact);
  $c->next_action($contact);
}

  sub POST_create :Action RequestModel(ContactRequest) ($self, $c, $r, $contact) {
    return $contact->set_from_request($r) ?
      $c->view->set_http_created(location => $c->uri($self->action_for('update'), $contact->id) ) :
        $c->view->set_http_bad_request;
  }

sub update :Chained(../setup) PathPart('') Args(1) Verbs(GET,PATCH,DELETE) ($self, $c, $id, $collection) {
  my $contact = $collection->find($id) // $c->detach_error(404, +{error=>"Contact id $id not found"});
  $c->view('HTML::Contact', contact => $contact);
  $c->next_action($contact);
}

  sub PATCH_update :Action RequestModel(ContactRequest) ($self, $c, $r, $contact) {
    return $contact->set_from_request($r) ?
      $c->view->set_http_ok :
        $c->view->set_http_bad_request;
  }

  sub DELETE_update :Action ($self, $c, $contact) {
    return $contact->delete && $c->redirect_to_action('#contacts');
  }

__PACKAGE__->meta->make_immutable;

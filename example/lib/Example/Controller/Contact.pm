package Example::Controller::Contact;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

has contact => (is=>'rw');

sub root :Chained(/auth) PathPart('contacts') CaptureArgs(0) ($self, $c) {
  $self->contact($c->user->new_contact);
  $c->view('HTML::Contact' => (contact => $self->contact));
} 

  sub create :Chained('root') PathPart('new') Args(0) Verbs(GET,POST) ($self, $c) { }

    sub GET_create :Action ($self, $c) { return $c->view->set_http_ok }

    sub POST_create :Action ($self, $c) {
      return $c->detach('_process_contact_request');
    }

  sub update :Chained('root') PathPart('') Args(1) Verbs(GET,PATCH,DELETE) ($self, $c, $id) {
    $self->contact->load_from_id($id) ||
      return $c->detach_error(404, +{error=>"Contact id $id not found"});
  }

    sub GET_update :Action ($self, $c) { return $c->view->set_http_ok }

    sub PATCH_update :Action ($self, $c) {
      return $c->detach('_process_contact_request');
    }

    sub DELETE_update :Action ($self, $c) {
      $self->contact->delete;
      return $c->redirect_to_action('#contacts');
    }

  sub _process_contact_request :Action RequestModel(ContactRequest) ($self, $c, $r) {
      return $self->contact->set_from_request($r) ?
        $c->redirect_to_action('#contacts') :
          $c->view->set_http_bad_request;
    }

__PACKAGE__->meta->make_immutable;
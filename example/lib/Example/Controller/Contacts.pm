package Example::Controller::Contacts;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

## TODO
## shouldn't person_id be in fields for (how does that impact security)
## allow $resultset->bulk_set_recursively  (and contemplate security)
## RequestModel needs "type Object" 'type Array'

sub setup :Chained(../auth) PathPart('contacts') CaptureArgs(0) ($self, $c, $user) {
  my $collection = $user->contacts;
  $c->next_action($collection);
}

  sub list :Chained(setup) PathPart('') Args(0) Verbs(GET,PATCH) Name(contacts) ($self, $c, $collection) {
    $c->view('HTML::Contacts', list => $collection);
    $c->next_action($collection);
  }

    sub PATCH :Action RequestModel(ContactsRequest) ($self, $c, $r, $collection) {
      $c->user->update($r->nested_params);
    }

__PACKAGE__->meta->make_immutable;

__END__

sub setup :Chained(../auth) PathPart('contacts') CaptureArgs(0) ($self, $c, $user) {
  my $collection = $user->contacts;
  $c->next_action($collection);
}

  sub prepare_response :Chained(setup) PathPart('') CaptureArgs(0) ($self, $c, $collection) {
    $c->view('HTML::Contacts', list => $collection);
    $c->next_action($collection);
  }

    sub method_not_allowed :METHOD(*) Chained(prepare_response) Args(0) ($self, $c, $collection) {
      $c->detach_error(405, allowed=>['GET', 'PATCH']);
    }
    sub list :GET Chained(prepare_response) Args(0) ($self, $c, $collection) { $c->view->set_http_ok }

    sub bulk_update :PATCH Chained(prepare_response) Args(0) RequestModel(ContactsRequest) ($self, $c, $r, $collection) {
      $c->user->update($r->nested_params);
    }


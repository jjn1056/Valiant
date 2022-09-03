package Example::Controller::Contacts;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

## TODO
## shouldn't person_id be in fields for (how does that impact security)
## allow $resultset->bulk_set_recursively  (and contemplate security)
## RequestModel needs "type Object" 'type Array'

sub contacts :Chained(../auth) CaptureArgs(0) ($self, $c, $user) {
  my $collection = $user->contacts;
  $c->next_action($collection);
}

  sub list :Chained(contacts) PathPart('') Args(0) Verbs(GET,PATCH) Name(contacts) ($self, $c, $collection) {
    $c->view('HTML::Contacts', list => $collection);
    $c->next_action($collection);
  }

    sub PATCH :Action RequestModel(ContactsRequest) ($self, $c, $r, $collection) {
      $c->user->update($r->nested_params);
    }

__PACKAGE__->meta->make_immutable;

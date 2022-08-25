package Example::Controller::Contacts;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

## TODO
## shouldn't person_id be in fields for (how does that impact security)
## allow $resultset->bulk_set_recursively  (and contemplate security)
## RequestModel needs "type Object" 'type Array'

sub root :Chained(/auth) PathPart('contacts') Args(0) Verbs(GET) Name(contacts) ($self, $c) {
  $c->view('HTML::Contacts',
    list => my $list = $c->user->contacts,
  );
}

  sub GET :Action ($self, $c) { return $c->view->set_http_ok }

  sub PATCH :Action RequestModel(ContactsRequest) ($self, $c, $r) {
    $c->user->update($r->nested_params);
  }

__PACKAGE__->meta->make_immutable;

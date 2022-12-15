package Example::Controller::Contacts;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

sub contacts :Chained(../auth) CaptureArgs(0) ($self, $c, $user) {
  my $collection = $user->contacts;
  $c->next_action($collection);
}

  sub list :GET Chained(contacts) PathPart('') Args(0) RequestModel(ContactsQuery)  Name(ContactsList) ($self, $c,  $collection, $contacts_query) {
    my $sessioned_query = $c->model('ContactsQuery::Session', $contacts_query);
    $c->view('HTML::Contacts', list => $collection->filter_by_request($sessioned_query));
  }

__PACKAGE__->meta->make_immutable;

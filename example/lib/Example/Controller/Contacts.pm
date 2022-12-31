package Example::Controller::Contacts;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

sub contacts :Chained(*Secured) CaptureArgs(0) ($self, $c, $user) {
  $c->action->next(my $contacts = $user->contacts);
}

  sub list :GET Chained(contacts) PathPart('') Args(0) QueryModel(ContactsQuery) Name(ContactsList) ($self, $c, $contacts, $contacts_query) {
    my $sessioned_query = $c->model('ContactsQuery::Session', $contacts_query);
    $c->view('HTML::Contacts', list => $contacts->filter_by_request($sessioned_query));
  }

__PACKAGE__->meta->make_immutable;

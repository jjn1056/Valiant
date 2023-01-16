package Example::Controller::Contacts;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

sub root :Chained(*Secured) PathPart('contacts') CaptureArgs(0) ($self, $c, $user) {
  $c->action->next(my $contacts = $user->contacts);
}

  sub setup :Chained(root) PathPart('') CaptureArgs(0) QueryModel(ContactsQuery) ($self, $c, $contacts, $contacts_query) {
    my $sessioned_query = $c->model('ContactsQuery::Session', $contacts_query);
    my $list = $contacts->filter_by_request($sessioned_query);
    $c->view('HTML::Contacts',
      list => $list,
      child_controller => $c->controller('Contacts::Contact') );
    $c->action->next($list);
  }

  sub list :GET Chained(setup) PathPart('') Args(0) ($self, $c, $list) {
    $c->view->set_http_ok;
  }

__PACKAGE__->meta->make_immutable;

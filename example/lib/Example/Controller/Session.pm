package Example::Controller::Session;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Catalyst::Controller';

sub login : Chained(/root) Args(0) Does(Verbs) Name(login) ($self, $c) {
  $c->redirect_to_action('#home') if $c->user; # Don't bother if already logged in
}

  # Might seem silly to use an empty model for such a small form but its better
  # to be consistent since its the pattern used for more complex stuff

  sub GET :Action ($self, $c) {
      return $c->view('Components::Login',
        person => $c->model('Schema::Person')->new_result(+{})
      )->http_ok;
  }

  sub POST :Action ($self, $c) {
    my ($username, $password) = $c
      ->structured_body(['person'], 'username', 'password')
      ->get('username', 'password');
    my $person = $c->authenticate($username, $password);

    return $c->view('Components::Login', person=>$person)->http_bad_request if $person->has_errors;
    return $c->redirect_to_action('#home');
  }

  sub logout : Chained(/auth) PathPart(logout) Args(0) ($self, $c) {
    $c->logout;
    return $c->redirect_to_action('#login');
  }

__PACKAGE__->meta->make_immutable;


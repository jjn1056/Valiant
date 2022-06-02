package Example::Controller::Session;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Catalyst::Controller';

sub login : Chained(/root) Args(0) Does(Verbs) Name(login) ($self, $c) {
  $c->redirect_to_action('#home') && $c->detach if $c->user->authenticated # Don't bother if already logged in
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

    return $person->has_errors ?
      $c->view('Components::Login', person=>$person)->http_bad_request
        : $c->redirect_to_action('#home');
  }

  sub logout : Chained(/auth) PathPart(logout) Args(0) ($self, $c) {
    $c->logout;
    return $c->redirect_to_action('#login');
  }

__PACKAGE__->meta->make_immutable;

__END__

package Example::Controller::Session;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'CatalystX::Controller::PerRequest';

has user => (
  is => 'ro',
  lazy => 1,
  required => 1,
  default => sub($self) { $self->c->user_store->new_result(+{}) },
);

sub login : Chained(/root) Args(0) Name(login) View(Login) ($self, $c) {
  $c->redirect_to_action('#home') if $c->user; # Don't bother if already logged in
}

  sub show :GET Chained(login) ($self, $c) { return $c->res->code(HTTP_OK) }

  sub authenticate :POST Chained(login) BodyRequest(LoginRequest) ($self, $c, $login_req) {
    my ($username, $password) = $login_req->get('username', 'password');
    my $user = $c->authenticate($username, $password);  # returning a full object allows you to inform the controller
                                                        # of extended error details like 'too many login fails', etc.
                                                        # and also setups an object with error info to pass to the view.
    return $user->has_errors ?
      $self->user($user) && $c->res->code(HTTP_BAD_REQUEST)
        : $c->redirect_to_action('#home');
  }

# Delegating the action view render this way allows you to add in centralize
# view modifications (such as a special wrapper for administrators).

sub end :Action Does(ViewResponse) { }

package Example::View::Login

use Moose;
use Example::Syntax;
use Example::Types 'PersonResult';

extends 'CatalystX::View::BasePerRequest';

has person => (
  is=>'ro',
  isa=>PersonResult,
  required=>1,
  depends=>'Controller.user',
);

sub render ($self, $c) { ... }


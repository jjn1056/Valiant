package Example::Controller::Session;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

has user => ( is=>'rw', required=>1, lazy=>1, default=>sub($self) { $self->ctx->users->unauthenticated_user } );

sub login : Chained(/root) Args(0) Does(Verbs) Name(login) View(Components::Login) ($self, $c) {
  $c->redirect_to_action('#home') && $c->detach if $c->user->authenticated # Don't bother if already logged in
}

  sub GET :Action ($self, $c) { return $c->res->code(200) }

  sub POST :Action RequestModel(LoginRequest) ($self, $c, $request) {
    $self->user($c->users->user_from_request($request));  # returning a full object allows you to inform the controller
                                                          # of extended error details like 'too many login fails', etc.
                                                          # and also setups an object with error info to pass to the view.
    return $self->user->has_errors ?
      $c->res->code(400)
        : $c->set_user($self->user) && $c->redirect_to_action('#home');
  }

  sub logout : Chained(/auth) PathPart(logout) Args(0) ($self, $c) {
    return $c->logout && $c->redirect_to_action('#login');
  }

__PACKAGE__->meta->make_immutable;

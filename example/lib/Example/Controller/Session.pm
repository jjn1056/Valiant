package Example::Controller::Session;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

sub login :Chained(*Root) CaptureArgs(0)  QueryModel(LoginQuery) ($self, $c, $user, $q) {
  $c->redirect_to_action('*home') && $c->detach if $user->authenticated; # Don't bother if already logged in
  $c->view('HTML::Login', user => $user);
  $c->view->post_login_redirect($q->post_login_redirect) if $q->has_post_login_redirect;
  $c->action->next($q);
}

  sub view :GET Chained(login) PathPart('') Args(0) Name(Login) ($self, $c, $q) { }

  sub do_login :POST Chained(login) PathPart('') Args(0) RequestModel(LoginRequest) ($self, $c, $q, $request) {
    return $c->view->set_http_bad_request unless $c->authenticate($request->person);
    return $c->res->redirect($q->post_login_redirect) if $q->has_post_login_redirect;
    return $c->redirect_to_action('*home');
  }

sub logout :GET Chained(*Secured) PathPart(logout) Args(0) ($self, $c, $user) {
  return $c->logout && $c->redirect_to_action('*Login');
}

__PACKAGE__->meta->make_immutable;

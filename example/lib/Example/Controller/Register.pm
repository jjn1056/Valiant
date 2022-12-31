package Example::Controller::Register;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

sub register :Chained(*Public) CaptureArgs(0) ($self, $c, $user) {
  return $c->redirect_to_action('#home') && $c->detach if $user->registered;
  $c->view('HTML::Register', registration => $user);
  $c->action->next($user);
}

  sub view :GET Chained(register) PathPart('') Args(0) ($self, $c, $user) { }

  sub create :POST Chained(register) PathPart('') Args(0) RequestModel(RegistrationRequest) ($self, $c, $user, $request) {
    return $user->register($request) ?
      $c->redirect_to_action('*Login') :
        $c->view->set_http_bad_request;
  }

__PACKAGE__->meta->make_immutable; 

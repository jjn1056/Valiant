package Example::Controller::Register;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

sub root :Chained(/root) PathPart(register) Args(0) Verbs(GET, POST) ($self, $c) {
  return $c->redirect_to_action('#home') && $c->detach
    if $c->user->registered;

  $c->view('HTML::Register', registration => $c->model('RegistrationForm', model=>$c->user));
}

  sub POST :Action RequestModel(RegistrationRequest) ($self, $c, $request) {    
    return $c->user->register($request) ?
      $c->redirect_to_action('#login') :
        $c->view->set_http_bad_request;
  }

__PACKAGE__->meta->make_immutable; 

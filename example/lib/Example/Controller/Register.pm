package Example::Controller::Register;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Catalyst::Controller';

sub root :Chained(/root) PathPart(register) Args(0) Does(Verbs)  ($self, $c) {
  return $c->redirect_to_action('#home') if $c->user;   # ->user->registered
  my $registration = $c->model('Schema::Person')->registration;
  my $view = $c->view('Components::Register', registration=>$registration);
  return $registration, $view;
}

  sub GET :Action ($self, $c, $person, $view) {
    return $view->http_ok;
  }

  sub POST :Action Does(RequestModel) RequestModel(RegistrationRequest) ($self, $c, $registration, $view, $request) {    
    $registration->register($request->nested_params);  ## Avoid DBIC specific API
    return $registration->valid ?
      $c->redirect_to_action('#login') :
        $view->http_bad_request;
  }

__PACKAGE__->meta->make_immutable;  

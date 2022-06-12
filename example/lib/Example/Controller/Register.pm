package Example::Controller::Register;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::ControllerPerRequest';

has registration => (
  is => 'ro',
  lazy => 1,
  required => 1,
  default => sub($self) { $self->ctx->users->registration  },
);

sub root :Chained(/root) PathPart(register) Args(0) Does(Verbs) View(Components::Register)  ($self, $c) {
  return $c->redirect_to_action('#home') && $c->detach if $c->user->registered;
}

  sub GET :Action ($self, $c) { return $c->res->code(200) }

  sub POST :Action RequestModel(RegistrationRequest) ($self, $c, $request) {    
    $self->registration->register($request);  ## Avoid DBIC specific API
    return $self->registration->valid ?
      $c->redirect_to_action('#login') :
        $c->res->code(400);
  }

__PACKAGE__->meta->make_immutable;  

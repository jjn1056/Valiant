package Example::Controller::Register;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

##  This data is scoped to the controller for which it makes sense, as opposed to
## how the stash is scoped to the entire request.  Plus you reduce the risk of typos
## in calling the stash which breaks stuff in hard to figure out ways.  Basically
## we have a strongly typed controller with a clear data access API.

has registration => (
  is => 'ro',
  lazy => 1,
  required => 1,
  default => sub($self) { $self->ctx->users->registration },
);

sub root :Chained(/root) PathPart(register) Args(0) Does(Verbs) View(HTML::Register)  ($self, $c) {
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

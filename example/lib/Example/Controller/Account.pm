package Example::Controller::Account;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

has account => (
  is=>'ro',
  required=>1,
  lazy=>1,
  default=>sub($self) { $self->ctx->user->account },
);

sub root :Chained(/auth) PathPart('account') Args(0) Does(Verbs) View(Components::Account) ($self, $c) { }

  sub GET :Action ($self, $c) { return $c->res->code(200) }

  sub PATCH :Action RequestModel(AccountRequest) ($self, $c, $request) {
    $self->account->update_account($request);
    return $self->account->valid ? 
      $c->res->code(200) : 
        $c->res->code(400);
  }

__PACKAGE__->meta->make_immutable;


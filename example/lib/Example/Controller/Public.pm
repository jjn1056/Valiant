package Example::Controller::Public;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

sub setup :Chained(../public) PathPart('') CaptureArgs(0) ($self, $c, $user) { }

  # Nothing here for now so just redirect to login
  sub public_home :Chained(setup) PathPart('') Args(0) ($self, $c) {
    return $c->redirect_to_action('#login') && $c->detach;
  }

__PACKAGE__->meta->make_immutable;

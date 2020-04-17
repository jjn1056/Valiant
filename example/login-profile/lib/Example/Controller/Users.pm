package Example::Controller::Users;

use Moose;
use MooseX::MethodAttributes;

extends 'Catalyst::Controller';

sub root :Chained(../root) PathPart('') CaptureArgs(0) {} 

  sub register :Chained(root) Args(0) {
    my ($self, $c) = @_;
    $c->stash(model=>$c->model('Register'));

  }


__PACKAGE__->meta->make_immutable;

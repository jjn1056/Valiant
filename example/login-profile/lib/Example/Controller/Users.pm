package Example::Controller::Users;

use Moose;
use MooseX::MethodAttributes;

extends 'Catalyst::Controller';

sub root :Chained(../root) PathPart('') CaptureArgs(0) {} 

  sub register :Chained(root) Args(0) {
    my ($self, $c) = @_;
    my $model = $c->model('Register');
    $c->redirect_to_action('/login') if $model->registered;
    $c->stash(model=>$model);
  }


__PACKAGE__->meta->make_immutable;

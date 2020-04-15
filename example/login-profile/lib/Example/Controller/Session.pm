package Example::Controller::Session;

use Moose;
use MooseX::MethodAttributes;

extends 'Catalyst::Controller';

sub root : Chained(../root) PathPart('') CaptureArgs(0) { }

  sub login : Chained(root) PathPart(login) Args(0) {
    my ($self, $c) = @_;
    return $c->redirect_to_action('../home')  if $c->user_exists
                                              || (my $model = $c->model('Authenticate'))->user_authenticated;
    $c->stash(model => $model);
    $c->go('/session/authenticate');
  }

  sub logout : Chained(root) PathPart(logout) Args(0) {
    my ($self, $c) = @_;
    $c->logout;
    $c->redirect_to_action('login');
  }

sub authenticate :Private {
  my ($self, $c) = @_;
}

__PACKAGE__->meta->make_immutable;

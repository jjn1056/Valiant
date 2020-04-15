package Example::Controller::Session;

use Moose;
use MooseX::MethodAttributes;

extends 'Catalyst::Controller';

sub root : Chained(../root) PathPart('') CaptureArgs(0) { }

  sub login : Chained(root) PathPart(login) Args(0) {
    my ($self, $c) = @_;
    $c->log->info(11111);
    $c->visit('authenticate');
    $c->log->info(22222);
    return $c->redirect_to_action('../home') if $c->user_exists;
  }

  sub logout : Chained(root) PathPart(logout) Args(0) {
    my ($self, $c) = @_;
    $c->logout;
    $c->redirect_to_action('login');
  }

sub authenticate :Private {
  my ($self, $c) = @_;
  $c->log->info(333333);
  $c->detach if $c->user_exists;
  $c->log->info(444444);
  $c->detach if (my $model = $c->model('Authenticate'))->user_authenticated;
  $c->log->info(555555);
  $c->stash(model => $model);
}

__PACKAGE__->meta->make_immutable;

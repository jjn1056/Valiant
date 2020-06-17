package Example::Controller::Root;

use Moose;
use MooseX::MethodAttributes;

extends 'Catalyst::Controller';

sub root :Chained(/) PathPart('') CaptureArgs(0) {} 

  sub not_found :Chained(root) PathPart('') Args { }

  sub register :Chained(root) Args(0) {
    my ($self, $c) = @_;
    my $model = $c->model('Register');
    $c->redirect_to_action('/login') if $model->registered;
    $c->stash(model=>$model);
  }

  sub authenticate :Chained(root) PathPart('') CaptureArgs() {
    my ($self, $c) = @_;
    return  if $c->user_exists
            || (my $model = $c->model('Authenticate'))->user_authenticated;

    $c->view(HTML => 'authenticate.ep', +{ model => $model });
    $c->detach;
  }

    sub login : Chained(authenticate) PathPart(login) Args(0) {
      my ($self, $c) = @_;
      return $c->redirect_to_action('profile');
    }

    sub profile :Chained(authenticate) PathPart('') Args(0) {
      my ($self, $c) = @_;
      my $model = $c->model('Profile');
      $c->stash(model=>$model);
    }

  sub logout : Chained(root) PathPart(logout) Args(0) {
    my ($self, $c) = @_;
    $c->logout;
    $c->redirect_to_action('login');
  }

sub end : ActionClass('RenderView') {}

__PACKAGE__->config(namespace=>'');
__PACKAGE__->meta->make_immutable;


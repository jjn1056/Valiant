package Example::Controller::Root;

use Moose;
use MooseX::MethodAttributes;

extends 'Catalyst::Controller';

sub root :Chained(/) PathPart('') CaptureArgs(0) {} 

  sub not_found :Chained(root) PathPart('') Args {
  }

  sub logout : Chained(root) PathPart(logout) {
    my ($self, $c) = @_;
    $c->logout;
    $c->redirect_to_action('home');
  }

  sub authenticate :Chained(root) PathPart('') CaptureArgs() {
    my ($self, $c) = @_;
    return if $c->user_exists;
    return if (my $model = $c->model('Authenticate'))->user_authenticated;
    $c->stash(template=>'authenticate.html', model=>$model);
    $c->detach;
  }

    sub home :Chained(authenticate) PathPart('') Args(0) {
      my ($self, $c) = @_;
      $c->model('Schema')->schema->diff($c->path_to('sql/schemas'));
    }

sub end : ActionClass('RenderView') {}

__PACKAGE__->config(namespace=>'');
__PACKAGE__->meta->make_immutable;

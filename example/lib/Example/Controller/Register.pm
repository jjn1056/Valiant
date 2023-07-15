package Example::Controller::Register;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

sub root :At('$path_end/...') Via('../public')  ($self, $c, $user) {
  return $c->redirect_to_action('/home/user_home') && $c->detach if $user->registered;
  $c->action->next($user);
}

  sub prepare_build :At('...') Via('root') ($self, $c, $user) {
    $self->view_for('build', registration => $user); 
    $c->action->next($user);
  }

    sub build :Get('new') Via('prepare_build') ($self, $c, $user) { }

    sub create :Post('') Via('prepare_build') BodyModel ($self, $c, $user, $bm) {
      return $user->register($bm) ?
        $c->redirect_to_action('/session/build') :
          $c->view->set_http_bad_request;
    }

__PACKAGE__->meta->make_immutable; 

package Example::Controller::Register;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

sub root :Via('../public') At('register/...') ($self, $c, $user) {
  return $c->redirect_to_action('/home/user_home') && $c->detach if $user->registered;
  $c->action->next($user);
}

  sub prepare_build :Via('root') At('...') ($self, $c, $user) {
    $self->view_for('build', registration => $user); 
    $c->action->next($user);
  }

    sub build :GET Via('prepare_build') At('new') ($self, $c, $user) { }

    sub create :POST Via('prepare_build') At('') BodyModel ($self, $c, $user, $request) {
      return $user->register($request) ?
        $c->redirect_to_action('/session/build') :
          $c->view->set_http_bad_request;
    }

__PACKAGE__->meta->make_immutable; 

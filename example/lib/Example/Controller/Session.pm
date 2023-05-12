package Example::Controller::Session;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Example::Controller';

has post_login_action => (is=>'ro', isa=>'Str', default=>'/home/user_home');

sub root :Via('../root') At('login/...') ($self, $c, $user) {
  return $c->redirect_to_action($self->post_login_action) && $c->detach
    if $user->authenticated;
  $c->action->next($user);
}

  sub prepare_build :Via('root') At('...') ($self, $c, $user) {
    $self->view_for('build', user => $user); 
    $c->action->next($user);
  }

    sub build :GET Via('prepare_build') At('')  ($self, $c, $user) {   }

    sub create :POST Via('prepare_build') At('') BodyModel ($self, $c, $user, $request) {
      return $c->authenticate($user, $request->person) ?
        $c->redirect_to_action($self->post_login_action) :
          $c->view->http_bad_request;
    }

sub logout :GET Via('../protected') At('logout') ($self, $c, $user) {
  return $c->logout && $c->redirect_to_action('build');
}

__PACKAGE__->meta->make_immutable;
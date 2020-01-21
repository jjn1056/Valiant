package MyApp::Controller::Session;

use MyApp::Controller;

sub root : Via(../root) At(...) ($self, $c) {}

  sub login : Via(root) At(login) ($self, $c) {
    return $c->redirect_to_action('home') if $c->user_exists;
    return $c->html(200, 'login.tx') unless $c->req->method eq 'POST';

    my ($user, $password) = @{$c->req->body_parameters}{qw/user password/};
    return $c->html(200, 'login.tx', +{errors=>'Invalid Credentials'})
      unless $c->authenticate({id=>$user, password=>$password});

    return $c->action->equals($self->action_for('login')) ?
      $c->redirect_to_action('../home') :
      $c->detach($c->action);
  }

  sub logout : Via(root) At(logout) ($self, $c) {
    $c->logout;
    $c->redirect_to_action('login');
  }

__PACKAGE__->meta->make_immutable;

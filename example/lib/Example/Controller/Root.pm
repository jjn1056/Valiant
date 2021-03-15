package Example::Controller::Root;

use Moose;
use MooseX::MethodAttributes;

extends 'Catalyst::Controller';

sub root :Chained(/) PathPart('') CaptureArgs(0) { } 

  sub not_found :Chained(root) PathPart('') Args { $_[1]->detach_error(404) }
  
  sub auth: Chained(root) PathPart('') CaptureArgs() {
    my ($self, $c) = @_;
    return if $c->user_exists;
    $c->redirect_to_action('login');
    $c->detach;
  }

  sub register :Chained(root) PathPart('register') Args(0) {
    my ($self, $c) = @_;
    $c->stash(person => my $model = $c->model('Schema::Person')->new_result($c->req->body_data||+{}));
    $model->insert if $c->req->method eq 'POST';
    return $c->redirect_to_action('login') if $model->in_storage;
  }

    sub home :Chained(auth) PathPart('home') Args(0) {
      my ($self, $c) = @_;
      $c->res->body('logged in! See <a href="/profile">Profile</>');  
    }

    sub profile :Chained(auth) PathPart('profile') Args(0) {
      my ($self, $c) = @_;
      $c->stash(person => my $model = $c->user->obj);
      $model->build_related_if_empty($_) for qw(profile);
      use Devel::Dwarn; Dwarn $c->req->body_data||+{};
      $model->update($c->req->body_data||+{}) if $c->req->method eq 'POST';
    }

    sub logout : Chained(auth) PathPart(logout) Args(0) {
      my ($self, $c) = @_;
      $c->logout;
      $c->redirect_to_action('login');
    }

  sub login : Chained(root) PathPart(login) Args(0) {
    my ($self, $c) = @_;
    my $message = '';
    if($c->req->method eq 'POST') {
      $c->redirect_to_action('home') if $c->authenticate({
          username=>$c->req->body_data->{username},
          password=>$c->req->body_data->{password},
        });
      $message = 'User not found';
    }
    $c->stash(error=>$message);
}

sub end : ActionClass('RenderView') {}

__PACKAGE__->config(namespace=>'');
__PACKAGE__->meta->make_immutable;


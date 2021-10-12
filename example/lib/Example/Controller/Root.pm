package Example::Controller::Root;

use Moose;
use MooseX::MethodAttributes;
use Devel::Dwarn; 

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
    $c->redirect_to_action('home') if $c->user_exists;

    my %params = $c->strong_body(
      ['person'], 
      'username', 'first_name', 'last_name', 
      'password', 'password_confirmation'
    )->to_hash;
    
    $c->stash(person => my $model = $c->model('Schema::Person')->new_result(\%params));
    $model->insert if $c->req->method eq 'POST';
    return $c->redirect_to_action('login') if $model->in_storage;
  }

    sub home :Chained(auth) PathPart('home') Args(0) {
      my ($self, $c) = @_;
      $c->res->body('logged in! See <a href="/profile">Profile</a> or <a href="/logout">Logout</a>');  
    }

    sub profile :Chained(auth) PathPart('profile') Args(0) Does(Verbs) {
      my ($self, $c) = @_;
      
      $c->stash(states => $c->model('Schema::State'));
      $c->stash(roles => $c->model('Schema::Role'));
      $c->stash(person => my $model = $c->model('Schema::Person')
        ->find(
          { 'me.id' => $c->user->id },
          { prefetch => ['profile', 'credit_cards', {person_roles => 'role' }] }
        )
      );

      $model->build_related_if_empty('profile'); # Needed since the relationsip is optional
    }

      sub GET_profile :Action {}

      sub POST_profile :Action {
        my ($self, $c) = @_;
        my %params = $c->strong_body(
          ['person'], 'username', 'first_name', 'last_name', 
          'profile' => [qw/id address city state_id zip phone_number birthday/],
          +{'person_roles' =>[qw/person_id role_id _delete/] },
          +{'credit_cards' => [qw/id card_number expiration _delete _add/]},
        )->to_hash;

        $c->stash->{person}->update(\%params);
      }

    sub logout : Chained(auth) PathPart(logout) Args(0) {
      my ($self, $c) = @_;
      $c->logout;
      $c->redirect_to_action('login');
    }

  sub login : Chained(root) PathPart(login) Args(0) {
    my ($self, $c) = @_;
    $c->redirect_to_action('home') if $c->user_exists;

    my $error = '';
    if($c->req->method eq 'POST') {
      my %params = $c->strong_body('username', 'password')->to_hash;
      $c->redirect_to_action('home') if $c->authenticate({
          username=>$params{username},
          password=>$params{password},
        });
      $error = 'User not found!';
    }
    $c->stash(error => $error);
}

sub end : ActionClass('RenderView') {}

__PACKAGE__->config(namespace=>'');
__PACKAGE__->meta->make_immutable;


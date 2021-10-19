package Example::Controller::Root;

use Moose;
use MooseX::MethodAttributes;

extends 'Catalyst::Controller';

sub root :Chained(/) PathPart('') CaptureArgs(0) Does(CurrentView) View(HTML) { } 

  sub not_found :Chained(root) PathPart('') Args { $_[1]->detach_error(404) }
  
  sub auth: Chained(root) PathPart('') CaptureArgs() {
    my ($self, $c) = @_;
    return if $c->user_exists;
    $c->redirect_to_action('login');
    $c->detach;
  }

  sub register :Chained(root) PathPart('register') Args(0) Does(Verbs) {
    my ($self, $c) = @_;
    $c->redirect_to_action('home') if $c->user_exists;
  }
  
    sub GET_register :Action {
      my ($self, $c) = @_;
      $c->stash(person => $c->model('Schema::Person')->new_result(+{}));
    }

    sub POST_register :Action {
      my ($self, $c) = @_;
      my %params = $c->structured_body(
        ['person'], 
        'username', 'first_name', 'last_name', 
        'password', 'password_confirmation'
      )->to_hash;
    
      $c->stash(person => my $model = $c->model('Schema::Person')->create(\%params));
      $c->redirect_to_action('login') if $model->valid;
    }

    sub home :Chained(auth) PathPart('home') Args(0) {
      my ($self, $c) = @_;
    }

    sub profile :Chained(auth) PathPart('profile') Args(0) Does(Verbs) Allow(GET,POST) {
      my ($self, $c) = @_;
      $c->stash(states => $c->model('Schema::State'));
      $c->stash(roles => $c->model('Schema::Role'));
      $c->stash(person => my $model = $c->model('Schema::Person')
        ->find(
          { 'me.id' => $c->user->id },
          { prefetch => ['profile', 'credit_cards', {person_roles => 'role' }] }
        )
      );
      $model->build_related_if_empty('profile'); # Needed since the relationship is optional
    }

      sub POST_profile :Action {
        my ($self, $c) = @_;
        my %params = $c->structured_body(
          ['person'], 'username', 'first_name', 'last_name', 
          'profile' => [qw/id address city state_id zip phone_number birthday/],
          +{'person_roles' =>[qw/person_id role_id _delete/] },
          +{'credit_cards' => [qw/id card_number expiration _delete _add/]},
        )->to_hash;

        $c->stash->{person}->context('profile')->update(\%params);
      }

    sub logout : Chained(auth) PathPart(logout) Args(0) {
      my ($self, $c) = @_;
      $c->logout;
      $c->redirect_to_action('login');
    }

  sub login : Chained(root) PathPart(login) Args(0) Does(Verbs) Allow(GET,POST) {
    my ($self, $c) = @_;
    $c->redirect_to_action('home') if $c->user_exists;
  }

    sub GET_login :Action {
      my ($self, $c) = @_;
      $c->stash(person => $c->model('Schema::Person')->new_result(+{})); 
    }

    sub POST_login :Action {
      my ($self, $c) = @_;
      my ($username, $password) = $c
        ->structured_body('username', 'password')
        ->get('username', 'password');

      $c->stash(person => my $person = $c->model('Schema::Person')->authenticate($username, $password));
      if(!$person->has_errors) {
        $c->authenticate(+{username=>$username, password=>$password});
        $c->redirect_to_action('home')
      }

    }

sub end : Action Does(RenderView) Does(RenderErrors) {}

__PACKAGE__->config(namespace=>'');
__PACKAGE__->meta->make_immutable;


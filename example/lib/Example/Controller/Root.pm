package Example::Controller::Root;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Catalyst::Controller';

sub root :Chained(/) PathPart('') CaptureArgs(0) Does(CurrentView) View(HTML) { } 

  sub not_found :Chained(root) PathPart('') Args ($self, $c, @args) { $c->detach_error(404) }
  
  sub auth: Chained(root) PathPart('') CaptureArgs() ($self, $c) {
    return if $c->user;
    $c->redirect_to_action('login');
    $c->detach;
  }

  sub register :Chained(root) PathPart('register') Args(0) Does(Verbs)  ($self, $c) {
    $c->redirect_to_action('home') if $c->user;
  }

    sub GET_register :Action ($self, $c) {
      my $person = $c->model('Schema::Person')->new_result(+{});
      return $c->view('Components::Register', person=>$person)->http_ok;
    }

    sub POST_register :Action ($self, $c) {
      my %params = $c->structured_body(
        ['person'], 
        'username', 'first_name', 'last_name', 
        'password', 'password_confirmation'
      )->to_hash;

      my $person = $c->model('Schema::Person')->create(\%params);

      return $c->redirect_to_action('login') if $person->valid;
      return $c->view('Components::Register', person=>$person)->http_bad_request;
    }

    sub home :Chained(auth) PathPart('home') Args(0) ($self, $c) { }

    sub profile :Chained(auth) PathPart('profile') Args(0) Does(Verbs) Allow(GET,PATCH) ($self, $c) {
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

      sub GET_profile :Action ($self, $c) {
        return $c->view('Components::Profile', %{$c->stash}{'person','roles','states'} )->http_ok;
      }

      sub PATCH_profile :Action ($self, $c) {
        my %params = $c->structured_body(
          ['person'], 'username', 'first_name', 'last_name', 
          'profile' => [qw/id address city state_id zip phone_number birthday/],
          +{'person_roles' =>[qw/person_id role_id _delete _nop/] },
          +{'credit_cards' => [qw/id card_number expiration _delete _add/]},
        )->to_hash;

        $c->stash->{person}->context('profile')->update(\%params);
        my $view = $c->view('Components::Profile', %{$c->stash}{'person','roles','states'});

        return $c->stash->{person}->valid ? $view->http_ok : $view->http_bad_request;
      }

    sub logout : Chained(auth) PathPart(logout) Args(0) ($self, $c) {
      $c->logout;
      $c->redirect_to_action('login');
    }

  sub login : Chained(root) PathPart(login) Args(0) Does(Verbs) ($self, $c) {
    $c->redirect_to_action('home') if $c->user; # Don't bother if already logged in
  }

    # Might seem silly to use an empty model for such a small form but its better
    # to be consistent since its the pattern used for more complex stuff

    sub GET_login :Action ($self, $c) {
        return $c->view('Components::Login',
          person => $c->model('Schema::Person')->new_result(+{})
        )->http_ok;
    }

    sub POST_login :Action ($self, $c) {
      my ($username, $password) = $c
        ->structured_body(['person'], 'username', 'password')
        ->get('username', 'password');
      my $person = $c->authenticate($username, $password);

      return $c->view('Components::Login', person=>$person)->http_bad_request if $person->has_errors;
      return $c->redirect_to_action('home');
    }

sub end : Action Does(RenderView) Does(RenderErrors) {}

__PACKAGE__->config(namespace=>'');
__PACKAGE__->meta->make_immutable;


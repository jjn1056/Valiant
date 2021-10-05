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
    $c->stash(person => my $model = $c->model('Schema::Person')->new_result($c->req->body_data->{person}||+{}));  # dont do this
    $model->insert if $c->req->method eq 'POST';
    return $c->redirect_to_action('login') if $model->in_storage;
  }

    sub home :Chained(auth) PathPart('home') Args(0) {
      my ($self, $c) = @_;
      $c->res->body('logged in! See <a href="/profile">Profile</a> or <a href="/logout">Logout</a>');  
    }

    sub profile :Chained(auth) PathPart('profile') Args(0) {
      my ($self, $c) = @_;
      
      $c->stash(states => $c->model('Schema::State'));
      $c->stash(roles => $c->model('Schema::Role'));
      $c->stash(person => my $model = $c->model('Schema::Person')
        ->find(
          { 'me.id'=>$c->user->id },
          { prefetch => ['profile', 'credit_cards', {person_roles => 'role' }] }
        )
      );

      $model->build_related_if_empty('profile'); # Needed since the relationsip is optional

      if(
        ($c->req->method eq 'POST') && 
        (my %params = %{ $c->req->body_data->{person}||+{} })
      ) {
        $model->context('profile')->update(\%params);
        Dwarn ['params' => \%params];
        Dwarn ['errors' => +{ $model->errors->to_hash(full_messages=>1) }] if $model->invalid;
      }
    }

    sub logout : Chained(auth) PathPart(logout) Args(0) {
      my ($self, $c) = @_;
      $c->logout;
      $c->redirect_to_action('login');
    }

  sub login : Chained(root) PathPart(login) Args(0) {
    my ($self, $c) = @_;
    my $error = '';
    if($c->req->method eq 'POST') {
      $c->redirect_to_action('home') if $c->authenticate({
          username=>$c->req->body_data->{username},
          password=>$c->req->body_data->{password},
        });
      $error = 'User not found!';
    }
    $c->stash(error => $error);
}

sub end : ActionClass('RenderView') {}

__PACKAGE__->config(namespace=>'');
__PACKAGE__->meta->make_immutable;


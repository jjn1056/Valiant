package Example::Controller::Profile;

use Moose;
use MooseX::MethodAttributes;
use Example::Syntax;

extends 'Catalyst::Controller';

sub root :Chained(/auth) PathPart('profile') Args(0) Does(Verbs) Allow(GET,PATCH) ($self, $c) {
  my $profile = $c->model('Schema::Person')->full_profile_for($c->user);
  my $view = $c->view('Components::Profile',
    profile  => $profile,
    states  => $profile->available_states,
    roles   => $profile->available_roles
  );
  return $profile, $view;
}

  sub GET :Action ($self, $c, $profile, $view) { return $view->http_ok }

  sub PATCH :Action ($self, $c, $profile, $view) {
    my %params = $c->structured_body(
      ['person'], 'username', 'first_name', 'last_name', 
      'profile' => [qw/id address city state_id zip phone_number birthday/],
      +{'person_roles' =>[qw/person_id role_id _delete _nop/] },
      +{'credit_cards' => [qw/id card_number expiration _delete _add/]},
    )->to_hash;

    $profile->context('profile')->update(\%params);

    return $profile->valid ? 
      $view->http_ok : 
        $view->http_bad_request;
  }

__PACKAGE__->meta->make_immutable;


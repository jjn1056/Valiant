package Example::Schema::ResultSet::Person;

use Example::Syntax;
use base 'Example::Schema::ResultSet';

sub find_by_id($self, $id) {
  return $self->find({id=>$id});
}

sub user_from_request($self, $request) {
  my ($username, $password) = $request->get('username', 'password');
  return $self->authenticate($username, $password);
}

sub authenticate($self, $username='', $password='') {
  my $user = $self->find({username=>$username});
  return $user if $user && $user->check_password($password);

  $user = $self->new_result({username=>$username});
  $user->errors->add(undef, 'Invalid login credentials');
  return $user;
}

sub account_for($self, $user) {
  my $account = $self->find(
    { 'me.id' => $user->id },
    { prefetch => ['profile', 'credit_cards', {person_roles => 'role' }] }
  );
  $account->build_related_if_empty('profile'); # Needed since the relationship is optional
  $account->profile->status('pending') unless defined($account->profile->status);
  return $account;
}

sub registration($self, $args=+{}) {
  return $self->new_result($args);
}

sub unauthenticated_user($self) {
  return $self->new_result(+{});  
}

1;

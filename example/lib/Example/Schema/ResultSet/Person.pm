package Example::Schema::ResultSet::Person;

use Example::Syntax;
use base 'Example::Schema::ResultSet';

sub find_by_id($self, $id) {
  return $self->find({id=>$id});
}

sub authenticate($self, $username='', $password='') {
  my $user = $self->find({username=>$username});
  return $user if $user && $user->check_password($password);

  $user = $self->new_result({username=>$username});
  $user->errors->add(undef, 'Invalid login credentials');
  return $user;
}

1;

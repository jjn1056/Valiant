package Example::Schema::ResultSet::Person;

use Example::Schema::ResultSetClass;

sub authenticate($self, $username='', $password='') {
  my $user = $self->find_or_new({username=>$username});
  return $user if $user->in_storage && $user->password eq $password;
  $user->errors->add(undef, 'Invalid login credentials');
  return $user;
}

1;

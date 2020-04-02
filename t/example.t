package Parent;

use Moo::Role;
use Role::Tiny ();

my @test;
sub test {
  my ($class, $arg) = @_;
  my $varname = "${class}::test";

  no strict "refs";
  push @$varname, $arg if defined($arg);

  return @$varname,
    map { $_->test } 
    grep { Role::Tiny::does_role($_, 'Parent') }
      $class->ancestors;
}

sub ancestors {
  my $class = shift;
  no strict "refs";
  my @ancestors = @{"${class}::ISA"};
  push @ancestors, $class->does_roles
    if $class->can('does_roles');
  return @ancestors;
}

package Role1;

use Moo::Role;
use MooX::TrackRoles;

with 'Parent';

__PACKAGE__->test("role1");

package A;

use Moo;
with 'Parent';

__PACKAGE__->test("foo1");

sub get {
  my $self = shift;
  return ref($self)->test;
}

package B;

use Moo;
extends 'A';
with 'Role1';

__PACKAGE__->test("foo2");
__PACKAGE__->test("foo3");

1;

use Test::Most;

ok my $a = A->new;
ok my $b = B->new;

is_deeply [$a->get], [
  "foo1",
];

is_deeply [$b->get], [
  "foo2",
  "foo3",
  "foo1",
  "role1",
];

done_testing;


package Local::Base;

use Moo::Role;

has attr1 => (
  is => 'ro',
  required => 1,
  default => sub { 100 },
);

package Local::Layer;

use Moo::Role;

with 'Local::Base';

has attr2 => (
  is => 'ro',
  lazy => 1,
  default => sub {
    return +{
      aaa => 111,
      bbb => $_[0]->attr1,
    };
  },
);

package Test::MooObject;

use Moo;

with 'Local::Layer';

package Test::RoleTinyObject;

use Role::Tiny::With;

with 'Local::Layer';

sub new { return bless +{}, shift }

package Local::Tests;

use Test::Most;

ok my $moo = Test::MooObject->new;

is_deeply $moo->attr2, +{
  aaa => 111,
  bbb => 100,
};

ok my $role_tiny_obj = Test::RoleTinyObject->new;

is_deeply $role_tiny_obj->attr2, +{
  aaa => 111,
  bbb => 100,
};

done_testing;

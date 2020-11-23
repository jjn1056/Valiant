use Test::Lib;
use Test::Most;

{
  package Local::Test::User;

  use Moo;
  use Valiant::Filters;

  has 'pick_first' => (is=>'ro', required=>1);
  has 'pick_last' => (is=>'ro', required=>1);
  has 'join' => (is=>'ro', required=>1);
  has 'sprintf' => (is=>'ro', required=>1);

  filters pick_first =>  (flatten=>+{pick=>'first'});
  filters pick_last =>  (flatten=>+{pick=>'last'});
  filters join =>  (flatten=>+{join=>','});
  filters sprintf =>  (flatten=>+{sprintf=>'%s-%s-%s'});
}

my $user = Local::Test::User->new(
  pick_first => [1,2,3],
  pick_last => [1,2,3],
  join => [1,2,3],
  sprintf => [1,2,3],

);

is $user->pick_first, 1;
is $user->pick_last, 3;
is $user->join, '1,2,3';
is $user->sprintf, '1-2-3';

done_testing;

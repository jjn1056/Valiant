use Test::Lib;
use Test::Most;

{
  package Local::Test::User;

  use Moo;
  use Valiant::Filters;

  has 'name' => (is=>'ro', required=>1);

  filters name => (
    collapse =>  1,
    trim => 1,
  );
}

my $user = Local::Test::User->new(name=>'   john     james      napiorkowski   ');

is $user->name, 'john james napiorkowski';

done_testing;

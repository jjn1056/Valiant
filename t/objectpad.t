use Test::Most;
use Test::Lib;
use OP::Person;

ok 1;

ok my $p = OP::Person->new(
  name=>'B',
  age=>4,
  retirement_date=>'2020');

ok $p->invalid;
#is_deeply +{ $p->errors->to_hash(full_messages=>1) },

use Devel::Dwarn;
Dwarn  $p->errors->to_hash(full_messages=>1);
##clone

done_testing;

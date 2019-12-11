use Test::Lib;
use Test::Most;
use Retiree;

ok my $retiree = Retiree->new(
  name=>'B',
  age=>4,
  retirement_date=>'2020');

$retiree->validate;

use Devel::Dwarn;
Dwarn $retiree->errors->details;
Dwarn +{ $retiree->errors->to_hash(full_messages=>1) };
Dwarn $retiree->errors->size;
Dwarn [$retiree->errors('_base')];

done_testing;

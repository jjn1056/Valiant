use Test::Lib;
use Test::Most;
use GlobalOptions;

ok my $object = GlobalOptions->new(name=>'B');

$object->validate;

use Devel::Dwarn;
Dwarn $object->errors->details;
Dwarn +{ $object->errors->to_hash(full_messages=>1) };
Dwarn $object->errors->size;

done_testing;

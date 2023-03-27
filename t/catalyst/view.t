use Test::Most;
use Test::Lib;


use Test::Lib;
use Catalyst::Test 'View::Example';


{
  ok my $res = request '/test';
  is $res->content, '';
}
done_testing;
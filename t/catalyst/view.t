use Test::Most;
use Test::Lib;


use Test::Lib;
use Catalyst::Test 'View::Example';

{
  ok my $res = request '/test';
  ok $res->content_type, 'text/html';
  warn $res->content;
}

{
  ok my $res = request '/simple';
  is $res->content, '<div>Hey</div>';
}

{
  ok my $res = request '/bits';
  is $res->content, '<div>stuff4</div>';
}

{
  ok my $res = request '/bits2';
  is $res->content, '<div>stuff4</div>';
}

{
  ok my $res = request '/stuff_long';
  is $res->content, '<div>Hey</div><p><div>there</div></p>';
}

done_testing;
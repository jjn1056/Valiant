use Test::Most;
use Test::Needs 'DBIO', 'DBIO::SQLite';

use_ok 'DBIO::Valiant::Util::Exception';
use_ok 'DBIO::Valiant::Util::Exception::TooManyRows';
use_ok 'DBIO::Valiant::Util::Exception::BadParameterFK';
use_ok 'DBIO::Valiant::Util::Exception::BadParameters';

{
  eval {
    DBIO::Valiant::Util::Exception->throw(msg => 'test message');
  };
  ok my $err = $@, 'base exception thrown';
  ok $err->isa('DBIO::Valiant::Util::Exception'), 'correct class';
  is $err->message, 'test message', 'message built from msg attribute';
}

{
  eval {
    DBIO::Valiant::Util::Exception::TooManyRows->throw(
      limit => 2, attempted => 3, related => 'credit_cards', me => 'person');
  };
  ok my $err = $@, 'TooManyRows thrown';
  ok $err->isa('DBIO::Valiant::Util::Exception::TooManyRows'), 'correct class';
  like $err->message, qr/credit_cards/, 'message names the relationship';
  like $err->message, qr/attempted 3/, 'message names the attempted count';
}

done_testing;

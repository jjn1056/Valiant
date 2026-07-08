# NOTE: requires an EMPTY scratch database -- deploy is unconditional and will die on rerun against an already-deployed database.
use Test::Most;

BEGIN {
  plan skip_all => 'set VALIANT_TEST_DBIO_PG_DSN (+_USER, _PASS) for the real-async PostgreSQL lane'
    unless $ENV{VALIANT_TEST_DBIO_PG_DSN};
}

# 'DBIO::Async::Storage' is the anticipated module name from the unreleased dbio-async dist; recheck the name when DBIO ships the per-connection async-mode subsystem.
use Test::Needs 'DBIO', 'DBIO::PostgreSQL', 'DBIO::Async::Storage';
use DBIO::Storage::DBI;

# The future_io per-connection async mode ships in DBIO releases AFTER
# 0.900000; on older DBIO this lane cannot run (connect would not bind a
# real async backend), so skip rather than mislead.
plan skip_all => 'installed DBIO lacks the per-connection async-mode subsystem (needs a post-0.900000 release)'
  unless DBIO::Storage::DBI->can('register_async_mode');

use Test::Lib;

require SchemaIO::Create;

ok my $schema = SchemaIO::Create->connect(
  $ENV{VALIANT_TEST_DBIO_PG_DSN},
  $ENV{VALIANT_TEST_DBIO_PG_USER}||'',
  $ENV{VALIANT_TEST_DBIO_PG_PASS}||'',
  { RaiseError => 1, async => 'future_io' },
), 'connected to PostgreSQL with future_io async mode';

$schema->deploy;

{
  # invalid simple create_async: validation gates the non-blocking insert
  ok my $f = $schema->resultset('Person')->create_async({
    username => 'x', first_name => 'john', last_name => 'napiorkowski', password => 'short',
  });
  ok my $person = $f->get, 'future resolved';
  ok $person->invalid, 'row invalid';
  ok !$person->in_storage, 'row not inserted';
  is $schema->resultset('Person')->count, 0, 'table empty';
}

{
  # valid simple create_async really goes through the async backend
  ok my $f = $schema->resultset('Person')->create_async({
    username => 'jjn', first_name => 'john', last_name => 'napiorkowski',
    password => 'hellohello', password_confirmation => 'hellohello',
  });
  ok my $person = $f->get, 'future resolved';
  ok $person->valid, 'row valid';
  ok $person->in_storage, 'row inserted';
  is $schema->resultset('Person')->count, 1, 'row in table';
}

# leave the scratch database clean for reruns
$schema->resultset('Person')->delete;

done_testing;

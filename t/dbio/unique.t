use Test::Most;
use Test::Needs 'DBIO', 'DBIO::SQLite';

# is_unique / unique => 1: rejects duplicates on create, rejects updates
# that change the column to a taken value, and short-circuits (skips the
# lookup entirely) when an in-storage row is updated without changing the
# unique column.
#
# The table deliberately has NO database-level unique constraint so a
# duplicate can be smuggled in with skip_validate; that existing duplicate
# is what proves the short-circuit, because the is_unique lookup would
# report the column value as taken if it actually ran.

{
  package UQ1::Schema::Result::Account;

  use base 'DBIO::Core';

  __PACKAGE__->load_components('Valiant::Result');
  __PACKAGE__->table("account");
  __PACKAGE__->resultset_class('UQ1::Schema::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    username => { data_type => 'varchar', is_nullable => 0, size => 48 },
    nickname => { data_type => 'varchar', is_nullable => 1, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->validates(username => (presence => 1, unique => 1));

  package UQ1::Schema::ResultSet;

  use base 'DBIO::ResultSet';

  __PACKAGE__->load_components('Valiant::ResultSet');

  package UQ1::Schema;

  use base 'DBIO::Schema';

  __PACKAGE__->register_class(Account => 'UQ1::Schema::Result::Account');
}

ok my $schema = UQ1::Schema->connect('dbi:SQLite:dbname=:memory:', '', '', { RaiseError => 1 });
$schema->deploy;

my $accounts = $schema->resultset('Account');

# --- create path ---

ok my $first = $accounts->create({ username => 'aaa' }), 'first create';
ok $first->valid, 'first username accepted';
ok $first->in_storage, 'inserted';

ok my $dup = $accounts->create({ username => 'aaa' }), 'duplicate create attempted';
ok $dup->invalid, 'duplicate rejected';
ok !$dup->in_storage, 'duplicate not inserted';
is_deeply [$dup->errors->full_messages_for('username')],
  ['Username chosen is not unique'],
  'expected uniqueness error';
is $accounts->search({username=>'aaa'})->count, 1, 'still exactly one aaa row';

# --- update path: changing the column to a taken value ---

ok my $second = $accounts->create({ username => 'bbb' }), 'second account';
ok $second->valid, 'second username accepted';

$second->update({ username => 'aaa' });
ok $second->invalid, 'update to a taken username rejected';
is_deeply [$second->errors->full_messages_for('username')],
  ['Username chosen is not unique'],
  'expected uniqueness error on the update path';
$second->discard_changes;
is $second->username, 'bbb', 'database value unchanged after refused update';

# --- update path: unchanged column short-circuits the lookup ---

{
  # smuggle in a duplicate 'bbb' behind the validator's back; from here on
  # any real is_unique lookup on 'bbb' would report the value as taken
  ok my $smuggled = $accounts->skip_validate->create({ username => 'bbb' }),
    'duplicate smuggled in with skip_validate';
  ok $smuggled->in_storage, 'smuggled row inserted';
  is $accounts->search({username=>'bbb'})->count, 2, 'two bbb rows in the table';

  # updating an unrelated column must not re-run the uniqueness lookup
  $second->update({ nickname => 'friendly' });
  ok $second->valid, 'update without touching username passes: lookup was skipped';
  $second->discard_changes;
  is $second->nickname, 'friendly', 'update stored';

  # re-submitting the same username value (the usual HTML form round trip)
  # is also "unchanged" and must not fail
  $second->update({ username => 'bbb', nickname => 'still friendly' });
  ok $second->valid, 'update re-submitting the same username value passes';
  $second->discard_changes;
  is $second->nickname, 'still friendly', 'update stored';

  # but actually changing it still validates: 'aaa' is taken
  $second->update({ username => 'aaa' });
  ok $second->invalid, 'changing the value still runs the lookup';
  is_deeply [$second->errors->full_messages_for('username')],
    ['Username chosen is not unique'],
    'expected uniqueness error';
}

done_testing;

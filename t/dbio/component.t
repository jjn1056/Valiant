use Test::Most;
use Test::Needs 'DBIO', 'DBIO::SQLite';

{
  package C1::Schema::Result::Album;

  use base 'DBIO::Core';

  __PACKAGE__->load_components('Valiant::Result');
  __PACKAGE__->table("album");
  __PACKAGE__->resultset_class('C1::Schema::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    artist_id => { data_type => 'integer', is_nullable => 1 },
    title => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->belongs_to(artist => 'C1::Schema::Result::Artist', { 'foreign.id' => 'self.artist_id' });
  __PACKAGE__->validates(title => (presence => 1, length => [3, 48]));

  package C1::Schema::Result::Artist;

  use base 'DBIO::Core';

  __PACKAGE__->load_components('Valiant::Result');
  __PACKAGE__->table("artist");
  __PACKAGE__->resultset_class('C1::Schema::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    name => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->has_many(albums => 'C1::Schema::Result::Album', { 'foreign.artist_id' => 'self.id' });
  __PACKAGE__->validates(name => (presence => 1, length => [2, 48]));
  __PACKAGE__->accept_nested_for('albums');

  package C1::Schema::ResultSet;

  use base 'DBIO::ResultSet';

  __PACKAGE__->load_components('Valiant::ResultSet');

  package C1::Schema;

  use base 'DBIO::Schema';

  __PACKAGE__->register_class(Artist => 'C1::Schema::Result::Artist');
  __PACKAGE__->register_class(Album => 'C1::Schema::Result::Album');
}

ok my $schema = C1::Schema->connect('dbi:SQLite:dbname=:memory:', '', '', { RaiseError => 1 });
$schema->deploy;

{
  # invalid create: returned unsaved, carrying errors
  ok my $bad = $schema->resultset('Artist')->create({ name => 'X' }), 'create returns a row';
  ok $bad->invalid, 'row is invalid';
  ok !$bad->in_storage, 'invalid row was NOT inserted';
  ok my ($msg) = $bad->errors->full_messages_for('name'), 'name has an error message';
}

{
  # valid create persists
  ok my $good = $schema->resultset('Artist')->create({ name => 'Nirvana' }), 'valid create';
  ok $good->valid, 'row is valid';
  ok $good->in_storage, 'valid row inserted';

  # update runs validations and refuses invalid changes
  $good->update({ name => 'N' });
  ok $good->invalid, 'update validation failed';
  $good->discard_changes;
  is $good->name, 'Nirvana', 'database value unchanged after invalid update';
}

{
  # nested create: child errors block the whole graph and aggregate upward
  ok my $nested = $schema->resultset('Artist')->create({
    name => 'Pearl Jam',
    albums => [ { title => 'Ten' }, { title => 'x' } ],
  }), 'nested create returns a row';
  ok $nested->invalid, 'parent invalid because a child is invalid';
  ok !$nested->in_storage, 'parent not inserted';
  ok my @msgs = $nested->errors->full_messages_for('albums'), 'albums aggregated an error';
  is $schema->resultset('Album')->count, 0, 'no albums inserted';
}

{
  # valid nested create persists parent and children
  ok my $ok_nested = $schema->resultset('Artist')->create({
    name => 'Soundgarden',
    albums => [ { title => 'Superunknown' } ],
  }), 'valid nested create';
  ok $ok_nested->valid, 'graph valid';
  ok $ok_nested->in_storage, 'parent inserted';
  is $schema->resultset('Album')->count, 1, 'child inserted';
}

{
  # skip_validation escape hatch on the resultset
  ok my $skipped = $schema->resultset('Artist')->skip_validate->create({ name => 'X' }),
    'create with skip_validate';
  ok $skipped->in_storage, 'validation was skipped so the row persisted';
}

done_testing;

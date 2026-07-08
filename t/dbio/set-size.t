use Test::Most;
use Test::Needs 'DBIO', 'DBIO::SQLite';

# SetSize boundaries: exactly min, one below, exactly max, one above,
# and skip_if_empty, on both the create and update paths, asserting the
# rendered too_few / too_many messages.

{
  package SS1::Schema::Result::Player;

  use base 'DBIO::Core';

  __PACKAGE__->load_components('Valiant::Result');
  __PACKAGE__->table("player");
  __PACKAGE__->resultset_class('SS1::Schema::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    team_id => { data_type => 'integer', is_nullable => 0, is_foreign_key => 1 },
    name => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->belongs_to(team => 'SS1::Schema::Result::Team', { 'foreign.id' => 'self.team_id' });
  __PACKAGE__->validates(name => (presence => 1));

  package SS1::Schema::Result::Team;

  use base 'DBIO::Core';

  __PACKAGE__->load_components('Valiant::Result');
  __PACKAGE__->table("team");
  __PACKAGE__->resultset_class('SS1::Schema::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    name => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->has_many(players => 'SS1::Schema::Result::Player', { 'foreign.team_id' => 'self.id' });
  __PACKAGE__->validates(name => (presence => 1));
  __PACKAGE__->accept_nested_for('players');
  __PACKAGE__->validates(players => (set_size => { min => 2, max => 3 }));

  package SS1::Schema::Result::LaxPlayer;

  use base 'DBIO::Core';

  __PACKAGE__->load_components('Valiant::Result');
  __PACKAGE__->table("player");
  __PACKAGE__->resultset_class('SS1::Schema::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    team_id => { data_type => 'integer', is_nullable => 0, is_foreign_key => 1 },
    name => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->belongs_to(team => 'SS1::Schema::Result::LaxTeam', { 'foreign.id' => 'self.team_id' });
  __PACKAGE__->validates(name => (presence => 1));

  package SS1::Schema::Result::LaxTeam;

  use base 'DBIO::Core';

  __PACKAGE__->load_components('Valiant::Result');
  __PACKAGE__->table("team");
  __PACKAGE__->resultset_class('SS1::Schema::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    name => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->has_many(players => 'SS1::Schema::Result::LaxPlayer', { 'foreign.team_id' => 'self.id' });
  __PACKAGE__->validates(name => (presence => 1));
  __PACKAGE__->accept_nested_for('players');
  __PACKAGE__->validates(players => (set_size => { min => 2, max => 3, skip_if_empty => 1 }));

  package SS1::Schema::ResultSet;

  use base 'DBIO::ResultSet';

  __PACKAGE__->load_components('Valiant::ResultSet');

  package SS1::Schema;

  use base 'DBIO::Schema';

  __PACKAGE__->register_class(Team => 'SS1::Schema::Result::Team');
  __PACKAGE__->register_class(Player => 'SS1::Schema::Result::Player');
  __PACKAGE__->register_class(LaxTeam => 'SS1::Schema::Result::LaxTeam');
  __PACKAGE__->register_class(LaxPlayer => 'SS1::Schema::Result::LaxPlayer');
}

ok my $schema = SS1::Schema->connect('dbi:SQLite:dbname=:memory:', '', '', { RaiseError => 1 });
$schema->deploy;

sub players { map { +{ name => "player $_" } } 1..shift }

# --- create path boundaries ---

{
  ok my $team = $schema->resultset('Team')->create({ name => 'Empty', players => [] }),
    'create with zero players';
  ok $team->invalid, 'zero is below min';
  is_deeply [$team->errors->full_messages_for('players')],
    ['Players has too few rows (minimum is 2)'],
    'too_few message rendered';
  ok !$team->in_storage, 'not inserted';
}

{
  ok my $team = $schema->resultset('Team')->create({ name => 'Solo', players => [players(1)] }),
    'create with one player';
  ok $team->invalid, 'one below min fails';
  is_deeply [$team->errors->full_messages_for('players')],
    ['Players has too few rows (minimum is 2)'],
    'too_few message rendered';
}

{
  ok my $team = $schema->resultset('Team')->create({ name => 'Duo', players => [players(2)] }),
    'create with exactly min players';
  ok $team->valid, 'exactly min passes';
  is $team->players->count, 2, 'players inserted';
}

{
  ok my $team = $schema->resultset('Team')->create({ name => 'Trio', players => [players(3)] }),
    'create with exactly max players';
  ok $team->valid, 'exactly max passes';
  is $team->players->count, 3, 'players inserted';
}

{
  ok my $team = $schema->resultset('Team')->create({ name => 'Crowd', players => [players(4)] }),
    'create with one over max';
  ok $team->invalid, 'one above max fails';
  is_deeply [$team->errors->full_messages_for('players')],
    ['Players has too many rows (maximum is 3)'],
    'too_many message rendered';
  ok !$team->in_storage, 'not inserted';
}

# --- update path: adding a row that pushes the set over max ---

{
  ok my $team = $schema->resultset('Team')->create({ name => 'Stable', players => [players(3)] });
  ok $team->valid, 'fixture valid';

  $team->update({ players => [ { name => 'one too many' } ] });
  ok $team->invalid, 'adding a fourth player via update fails';
  is_deeply [$team->errors->full_messages_for('players')],
    ['Players has too many rows (maximum is 3)'],
    'too_many message rendered on the update path';
  is $schema->resultset('Player')->search({team_id=>$team->id})->count, 3,
    'database still has exactly the original three';
}

# --- skip_if_empty ---

{
  ok my $team = $schema->resultset('LaxTeam')->create({ name => 'Ghosts', players => [] }),
    'create with zero players and skip_if_empty';
  ok $team->valid, 'empty set skipped entirely';
  ok $team->in_storage, 'inserted';
}

{
  ok my $team = $schema->resultset('LaxTeam')->create({ name => 'Lonely', players => [players(1)] }),
    'create with one player and skip_if_empty';
  ok $team->invalid, 'skip_if_empty does not excuse a non-empty set below min';
  is_deeply [$team->errors->full_messages_for('players')],
    ['Players has too few rows (minimum is 2)'],
    'too_few message rendered';
}

done_testing;

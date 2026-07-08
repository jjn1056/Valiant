use Test::Most;
use Test::Needs 'DBIO', 'DBIO::SQLite';

# DBIO::Valiant::Validator::Result and undefined related results: on an
# optional single relation (might_have, LEFT join) an absent related row
# is fine; on a required single relation (belongs_to over a non-nullable
# FK) it is an error.

{
  package VR1::Schema::Result::Boss;

  use base 'DBIO::Core';

  __PACKAGE__->load_components('Valiant::Result');
  __PACKAGE__->table("boss");
  __PACKAGE__->resultset_class('VR1::Schema::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    name => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->validates(name => (presence => 1, length => [2, 48]));

  package VR1::Schema::Result::Sidekick;

  use base 'DBIO::Core';

  __PACKAGE__->load_components('Valiant::Result');
  __PACKAGE__->table("sidekick");
  __PACKAGE__->resultset_class('VR1::Schema::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    hero_id => { data_type => 'integer', is_nullable => 0, is_foreign_key => 1 },
    title => { data_type => 'varchar', is_nullable => 0, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->belongs_to(hero => 'VR1::Schema::Result::Hero', { 'foreign.id' => 'self.hero_id' });
  __PACKAGE__->validates(title => (presence => 1, length => [3, 48]));

  package VR1::Schema::Result::Hero;

  use base 'DBIO::Core';

  __PACKAGE__->load_components('Valiant::Result');
  __PACKAGE__->table("hero");
  __PACKAGE__->resultset_class('VR1::Schema::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    name => { data_type => 'varchar', is_nullable => 0, size => 48 },
    boss_id => { data_type => 'integer', is_nullable => 0, is_foreign_key => 1 },
  );
  __PACKAGE__->set_primary_key("id");
  __PACKAGE__->belongs_to(boss => 'VR1::Schema::Result::Boss', { 'foreign.id' => 'self.boss_id' });
  __PACKAGE__->might_have(sidekick => 'VR1::Schema::Result::Sidekick', { 'foreign.hero_id' => 'self.id' });
  __PACKAGE__->validates(name => (presence => 1, length => [2, 48]));
  __PACKAGE__->accept_nested_for('boss');      # adds validates boss => (result => {validations=>1})
  __PACKAGE__->accept_nested_for('sidekick');  # adds validates sidekick => (result => {validations=>1})

  package VR1::Schema::ResultSet;

  use base 'DBIO::ResultSet';

  __PACKAGE__->load_components('Valiant::ResultSet');

  package VR1::Schema;

  use base 'DBIO::Schema';

  __PACKAGE__->register_class(Boss => 'VR1::Schema::Result::Boss');
  __PACKAGE__->register_class(Sidekick => 'VR1::Schema::Result::Sidekick');
  __PACKAGE__->register_class(Hero => 'VR1::Schema::Result::Hero');
}

ok my $schema = VR1::Schema->connect('dbi:SQLite:dbname=:memory:', '', '', { RaiseError => 1 });
$schema->deploy;

# --- undef related: optional relation passes, required relation fails ---

{
  ok my $hero = $schema->resultset('Hero')->create({ name => 'Batman' }),
    'create with neither related row';
  ok $hero->invalid, 'invalid';
  ok !$hero->in_storage, 'not inserted';
  is_deeply +{$hero->errors->to_hash(full_messages=>1)}, +{
    boss => [
      "Boss Is Invalid",
    ],
  }, 'required belongs_to flags the missing result; the might_have stays silent';
  is_deeply [$hero->errors->full_messages_for('sidekick')], [],
    'no error at all for the optional relation';
}

# --- required relation supplied and valid: no error ---

{
  ok my $hero = $schema->resultset('Hero')->create({
    name => 'Robin',
    boss => { name => 'Batman Inc' },
  }), 'create with a valid required related row';
  ok $hero->valid, 'valid';
  ok $hero->in_storage, 'inserted';
  ok $hero->boss->in_storage, 'related row inserted';
  is $hero->boss->name, 'Batman Inc', 'linked to the right row';
}

# --- optional relation supplied but invalid: aggregates as usual ---

{
  ok my $hero = $schema->resultset('Hero')->create({
    name => 'Nightwing',
    boss => { name => 'Batman Inc' },
    sidekick => { title => 'x' },
  }), 'create with an invalid optional related row';
  ok $hero->invalid, 'invalid';
  ok !$hero->in_storage, 'not inserted';
  is_deeply [$hero->errors->full_messages_for('sidekick')],
    ["Sidekick Is Invalid"],
    'optional relation present-but-invalid is still an error';
  is_deeply [$hero->errors->full_messages_for('sidekick.title')],
    ["Sidekick Title is too short (minimum is 3 characters)"],
    'nested errors imported under the relation name';
}

# --- optional relation supplied and valid ---

{
  ok my $hero = $schema->resultset('Hero')->create({
    name => 'Red Hood',
    boss => { name => 'Batman Inc' },
    sidekick => { title => 'Understudy' },
  }), 'create with a valid optional related row';
  ok $hero->valid, 'valid';
  ok $hero->in_storage, 'inserted';
  ok $hero->sidekick->in_storage, 'optional related row inserted';
}

done_testing;

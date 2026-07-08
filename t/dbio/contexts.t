use Test::Most;
use Test::Needs 'DBIO', 'DBIO::SQLite';

# Validation contexts end-to-end: the automatic 'create' and 'update'
# contexts, user-supplied __context on create, update and new_result, and
# the guarantee that context-scoped rules fire only in their context.

{
  package CTX1::Schema::Result::Gadget;

  use base 'DBIO::Core';

  __PACKAGE__->load_components('Valiant::Result');
  __PACKAGE__->table("gadget");
  __PACKAGE__->resultset_class('CTX1::Schema::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    name => { data_type => 'varchar', is_nullable => 0, size => 48 },
    on_create_note => { data_type => 'varchar', is_nullable => 1, size => 48 },
    on_update_note => { data_type => 'varchar', is_nullable => 1, size => 48 },
    on_special_note => { data_type => 'varchar', is_nullable => 1, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");

  __PACKAGE__->validates(name => (presence => 1));
  __PACKAGE__->validates(on_create_note => (presence => 1, on => 'create'));
  __PACKAGE__->validates(on_update_note => (presence => 1, on => 'update'));
  __PACKAGE__->validates(on_special_note => (presence => 1, on => 'special'));

  package CTX1::Schema::ResultSet;

  use base 'DBIO::ResultSet';

  __PACKAGE__->load_components('Valiant::ResultSet');

  package CTX1::Schema;

  use base 'DBIO::Schema';

  __PACKAGE__->register_class(Gadget => 'CTX1::Schema::Result::Gadget');
}

ok my $schema = CTX1::Schema->connect('dbi:SQLite:dbname=:memory:', '', '', { RaiseError => 1 });
$schema->deploy;

# --- automatic 'create' context ---

{
  ok my $gadget = $schema->resultset('Gadget')->create({ name => 'widget' }),
    'create without the create-scoped column';
  ok $gadget->invalid, 'invalid';
  ok !$gadget->in_storage, 'not inserted';
  is_deeply +{$gadget->errors->to_hash(full_messages=>1)}, +{
    on_create_note => [
      "On Create Note can't be blank",
    ],
  }, 'only the create-scoped rule fired: update and special rules stayed quiet';
}

# --- automatic 'update' context ---

{
  ok my $gadget = $schema->resultset('Gadget')->create({
    name => 'widget', on_create_note => 'made in create',
  }), 'valid create';
  ok $gadget->valid, 'valid';
  ok $gadget->in_storage, 'inserted';

  $gadget->update({ name => 'renamed' });
  ok $gadget->invalid, 'update invalid';
  is_deeply +{$gadget->errors->to_hash(full_messages=>1)}, +{
    on_update_note => [
      "On Update Note can't be blank",
    ],
  }, 'only the update-scoped rule fired: the create rule did not re-fire';
  $gadget->discard_changes;
  is $gadget->name, 'widget', 'invalid update did not reach the database';

  $gadget->update({ name => 'renamed', on_update_note => 'changed in update' });
  ok $gadget->valid, 'update valid once the update-scoped column is supplied';
  $gadget->discard_changes;
  is $gadget->name, 'renamed', 'valid update stored';
}

# --- user __context on create (scalar and array forms) ---

{
  ok my $gadget = $schema->resultset('Gadget')->create({
    __context => 'special',
    name => 'widget', on_create_note => 'note',
  }), 'create with scalar __context';
  ok $gadget->invalid, 'invalid';
  is_deeply +{$gadget->errors->to_hash(full_messages=>1)}, +{
    on_special_note => [
      "On Special Note can't be blank",
    ],
  }, 'special rule fired alongside the (satisfied) automatic create rule';

  ok my $gadget2 = $schema->resultset('Gadget')->create({
    __context => ['special'],
    name => 'widget', on_create_note => 'note', on_special_note => 'special note',
  }), 'create with arrayref __context and all required columns';
  ok $gadget2->valid, 'valid';
  ok $gadget2->in_storage, 'inserted';
}

# --- user __context on update ---

{
  ok my $gadget = $schema->resultset('Gadget')->create({
    name => 'widget', on_create_note => 'note',
  });
  ok $gadget->valid, 'fixture valid';

  $gadget->update({
    __context => 'special',
    on_update_note => 'update note',
  });
  ok $gadget->invalid, 'update with __context invalid';
  is_deeply +{$gadget->errors->to_hash(full_messages=>1)}, +{
    on_special_note => [
      "On Special Note can't be blank",
    ],
  }, 'special rule fired on update via __context';

  $gadget->update({
    __context => 'special',
    on_update_note => 'update note',
    on_special_note => 'special note',
  });
  ok $gadget->valid, 'valid once the special-scoped column is supplied';
}

# --- user __context on new_result: applied when the row is inserted ---

{
  ok my $gadget = $schema->resultset('Gadget')->new_result({
    __context => 'special',
    name => 'widget', on_create_note => 'note',
  }), 'new_result with __context';
  ok !$gadget->has_errors, 'no validation ran at new_result time';

  $gadget->insert;
  ok $gadget->invalid, 'insert ran the validations';
  ok !$gadget->in_storage, 'not inserted';
  is_deeply +{$gadget->errors->to_hash(full_messages=>1)}, +{
    on_special_note => [
      "On Special Note can't be blank",
    ],
  }, '__context stored on new_result was applied at insert';

  $gadget->on_special_note('special note');
  $gadget->insert;
  ok $gadget->valid, 'valid after supplying the special column';
  ok $gadget->in_storage, 'inserted';
}

done_testing;

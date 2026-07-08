use Test::Most;
use Test::Needs 'DBIO', 'DBIO::SQLite';

# Column-definition metadata: 'validates' and 'filters' keys inside
# add_columns info hashes are picked up by the register_column override,
# turned into declared validations / filters, and stripped from the
# column info itself.

{
  package CI1::Schema::Result::Widget;

  use base 'DBIO::Core';

  __PACKAGE__->load_components('Valiant::Result');
  __PACKAGE__->table("widget");
  __PACKAGE__->resultset_class('CI1::Schema::ResultSet');
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    name => {
      data_type => 'varchar',
      is_nullable => 0,
      size => 48,
      filters => [ trim => 1 ],
      validates => [ presence => 1, length => [3, 24] ],
    },
    note => { data_type => 'varchar', is_nullable => 1, size => 48 },
  );
  __PACKAGE__->set_primary_key("id");

  package CI1::Schema::ResultSet;

  use base 'DBIO::ResultSet';

  __PACKAGE__->load_components('Valiant::ResultSet');

  package CI1::Schema;

  use base 'DBIO::Schema';

  __PACKAGE__->register_class(Widget => 'CI1::Schema::Result::Widget');
}

# the keys are consumed by register_column, not left in the column info
{
  my $info = CI1::Schema::Result::Widget->column_info('name');
  ok !exists $info->{validates}, "'validates' key stripped from column info";
  ok !exists $info->{filters}, "'filters' key stripped from column info";
  is $info->{size}, 48, 'ordinary column info intact';
}

ok my $schema = CI1::Schema->connect('dbi:SQLite:dbname=:memory:', '', '', { RaiseError => 1 });
$schema->deploy;

# validations declared via the column info fire like any other
{
  ok my $bad = $schema->resultset('Widget')->create({ name => 'xy' }),
    'create with a name violating the column-info validation';
  ok $bad->invalid, 'row invalid';
  ok !$bad->in_storage, 'row not inserted';
  is_deeply [$bad->errors->full_messages_for('name')],
    ['Name is too short (minimum is 3 characters)'],
    'column-info validation produced the expected error';

  ok my $good = $schema->resultset('Widget')->create({ name => 'proper name' }),
    'create with a valid name';
  ok $good->valid, 'row valid';
  ok $good->in_storage, 'row inserted';
}

# filters declared via the column info run at construction time
{
  ok my $widget = $schema->resultset('Widget')->create({ name => '   padded   ' }),
    'create with a padded name';
  ok $widget->valid, 'row valid';
  is $widget->name, 'padded', 'trim filter from the column info was applied';
  $widget->discard_changes;
  is $widget->name, 'padded', 'trimmed value is what was stored';

  ok my $plain = $schema->resultset('Widget')->create({ name => 'untouched' });
  is $plain->name, 'untouched', 'filter leaves already-clean values alone';
}

# a column without those keys gets no implicit validation
{
  ok my $widget = $schema->resultset('Widget')->create({ name => 'named', note => 'x' }),
    'create with an unvalidated column';
  ok $widget->valid, 'no validation attached to the plain column';
  is_deeply [$widget->errors->full_messages_for('note')], [], 'no errors for note';
}

done_testing;

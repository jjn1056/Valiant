use Test::Most;
use Test::Needs 'DBIO', 'DBIO::SQLite';

{
  package Env00::Schema::Result::Widget;

  use base 'DBIO::Core';

  __PACKAGE__->table("widget");
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
    name => { data_type => 'varchar', is_nullable => 0, size => 24 },
  );
  __PACKAGE__->set_primary_key("id");

  package Env00::Schema;

  use base 'DBIO::Schema';

  __PACKAGE__->register_class(Widget => 'Env00::Schema::Result::Widget');
}

ok my $schema = Env00::Schema->connect('dbi:SQLite:dbname=:memory:', '', '', { RaiseError => 1 }),
  'connected in-memory SQLite via DBIO';
$schema->deploy;

ok my $widget = $schema->resultset('Widget')->create({ name => 'test' }), 'created a row';
ok $widget->id, 'autoinc PK came back';
is $schema->resultset('Widget')->count, 1, 'count is 1';

done_testing;

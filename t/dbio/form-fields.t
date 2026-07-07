use Test::Most;
use Test::Needs 'DBIO', 'DBIO::SQLite';

{
  package FF::Schema::Result::Status;

  use base 'DBIO::Core';

  __PACKAGE__->load_components('Valiant::Result::HTML::FormFields', 'Valiant::Result');
  __PACKAGE__->table("status");
  __PACKAGE__->add_columns(
    id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1, tags => ['option_value'] },
    label => { data_type => 'varchar', is_nullable => 0, size => 24, tags => ['option_label'] },
  );
  __PACKAGE__->set_primary_key("id");

  package FF::Schema;

  use base 'DBIO::Schema';

  __PACKAGE__->register_class(Status => 'FF::Schema::Result::Status');
}

is_deeply [FF::Schema::Result::Status->tags_by_column('label')], ['option_label'],
  'tags_by_column reads tag metadata from column info';
is_deeply [FF::Schema::Result::Status->columns_by_tag('option_label')], ['label'],
  'columns_by_tag reverse lookup';

ok my $schema = FF::Schema->connect('dbi:SQLite:dbname=:memory:', '', '', { RaiseError => 1 });
$schema->deploy;
ok my $status = $schema->resultset('Status')->create({ label => 'active' });
is $status->read_attribute_for_html('label'), 'active', 'read_attribute_for_html reads column value';
is $status->read_attribute_for_html('_add'), 1, '_add pseudo attribute';

done_testing;

package Example::Schema::Result::Role;

use Example::Syntax;
use base 'Example::Schema::Result';

__PACKAGE__->table("role");

__PACKAGE__->add_columns(
  id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1, tags => ['checkbox_value'] },
  label => { data_type => 'varchar', is_nullable => 0, size => '24', tags=>['checkbox_label'] },
);

__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(['label']);

__PACKAGE__->has_many(
  person_roles =>
  'Example::Schema::Result::PersonRole',
  { 'foreign.role_id' => 'self.id' }
);

1;

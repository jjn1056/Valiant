package Schema::Nested::Result::OneOne;

use base 'Schema::Result';

__PACKAGE__->table("one_one");
__PACKAGE__->add_columns(
  id => { data_type => 'bigint', is_nullable => 0, is_auto_increment => 1 },
  value => { data_type => 'varchar', is_nullable => 0, size => 48 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->has_one(
  one =>
  'Schema::Nested::Result::One',
  { 'foreign.one_id' => 'self.id' }
);

__PACKAGE__->accept_nested_for('one');
__PACKAGE__->add_unique_constraint(['value']);
__PACKAGE__->validates(value => ( presence=>1, length=>[3,24], unique=>1 ));
__PACKAGE__->validates(one => ( presence=>1, result=>+{validations=>1} ));

1;

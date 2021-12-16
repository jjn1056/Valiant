package Schema::Nested::Result::XBottom;

use base 'Schema::Result';

__PACKAGE__->table("bottom");

__PACKAGE__->add_columns(
  bottom_id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
  bottom_value => { data_type => 'varchar', is_nullable => 0, size => 48 },
  middle_id => { data_type => 'integer', is_nullable => 0, is_foreign_key => 1 }
);

__PACKAGE__->set_primary_key("bottom_id");

__PACKAGE__->belongs_to(
  middle =>
  'Schema::Nested::Result::XMiddle',
  { 'foreign.middle_id' => 'self.middle_id' },
);

__PACKAGE__->validates(bottom_value => (presence=>1, length=>[4,48]));

1;

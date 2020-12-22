package Schema::Create::Result::Many;

use base 'Schema::Result';

__PACKAGE__->table("many");

__PACKAGE__->add_columns(
  id => { data_type => 'bigint', is_nullable => 0, is_auto_increment => 1 },
  person_id => { data_type => 'integer', is_nullable => 0, is_foreign_key => 1 },
  address => { data_type => 'varchar', is_nullable => 0, size => 48 },
  city => { data_type => 'varchar', is_nullable => 0, size => 32 },
  zip => { data_type => 'varchar', is_nullable => 0, size => 5 },
  birthday => { data_type => 'date', is_nullable => 1 },
);

__PACKAGE__->validates(address => (presence=>1, length=>[2,48]));
__PACKAGE__->validates(city => (presence=>1, length=>[2,32]));
__PACKAGE__->validates(zip => (presence=>1, format=>'zip', on=>['create','update'])); # context here to make sure context passed to nested
__PACKAGE__->validates(birthday => (
    date => {
      max => sub { pop->now->subtract(days=>2) }, 
      min => sub { pop->years_ago(30) }, 
    }
  )
);

__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(['id','person_id']);

__PACKAGE__->belongs_to(
  person =>
  'Schema::Create::Result::Person',
  { 'foreign.id' => 'self.person_id' }
);

1;

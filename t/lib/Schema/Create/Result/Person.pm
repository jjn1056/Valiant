package Schema::Create::Result::Person;

use base 'Schema::Result';

__PACKAGE__->table("person");

__PACKAGE__->add_columns(
  id => { data_type => 'bigint', is_nullable => 0, is_auto_increment => 1 },
  username => { data_type => 'varchar', is_nullable => 0, size => 48 },
  first_name => { data_type => 'varchar', is_nullable => 0, size => 24 },
  last_name => { data_type => 'varchar', is_nullable => 0, size => 48 },
  password => { data_type => 'varchar', is_nullable => 0, size => 64 },
);

__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(['username']);

__PACKAGE__->filters(username => trim => 1);
__PACKAGE__->validates(username => presence=>1, length=>[3,24], format=>'alpha_numeric', unique=>1);
__PACKAGE__->validates(first_name => (presence=>1, length=>[2,24]));
__PACKAGE__->validates(last_name => (presence=>1, length=>[2,48]));
__PACKAGE__->validates(password => presence=>1, length=>[8,24]);
__PACKAGE__->validates(password => confirmation => { on=>'create' } );
__PACKAGE__->validates(password => confirmation => { 
    on => 'update',
    if => 'is_column_changed', # This method defined by DBIx::Class::Row
  });
 
 # nested validations run only if the relation exists since this is optional relation
__PACKAGE__->validates(profile => (result=>+{validations=>1} ));

__PACKAGE__->might_have(
  profile =>
  'Schema::Create::Result::Profile',
  { 'foreign.person_id' => 'self.id' }
);

1;

package SchemaIO::Create::Result::Person;

use DBIO::Candy -base => 'SchemaIO::Result';

table "person";

column id => { data_type => 'bigint', is_nullable => 0, is_auto_increment => 1 };
column username => { data_type => 'varchar', is_nullable => 0, size => 48 };
column first_name => { data_type => 'varchar', is_nullable => 0, size => 24 };
column last_name => { data_type => 'varchar', is_nullable => 0, size => 48 };
column password => { data_type => 'varchar', is_nullable => 0, size => 64 };

primary_key "id";
unique_constraint ['username'];

might_have profile => (
  'SchemaIO::Create::Result::Profile',
  { 'foreign.person_id' => 'self.id' }
);

filters username => (trim => 1);

validates username => (presence=>1, length=>[3,24], format=>'alpha_numeric', unique=>1);
validates first_name => (presence=>1, length=>[2,24]);
validates last_name => (presence=>1, length=>[2,48]);
validates password => (presence=>1, length=>[8,24]);
validates password => (confirmation => { on=>'create' } );
validates password => (confirmation => { 
    on => 'update',
    if => 'is_column_changed', # This method defined by DBIO::Row
  });
 
accept_nested_for 'profile', {update_only=>1};

1;

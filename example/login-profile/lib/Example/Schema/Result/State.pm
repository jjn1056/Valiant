package Example::Schema::Result::State;

use strict;
use warnings;

use base 'Example::Schema::Result';

__PACKAGE__->table("state");
__PACKAGE__->load_components(qw/Valiant::Result/);

__PACKAGE__->add_columns(
  id => { data_type => 'integer', is_nullable => 0, is_auto_increment => 1 },
  name => { data_type => 'varchar', is_nullable => 0, size => '24' },
  abbreviation => { data_type => 'varchar', is_nullable => 0, size => '24' },
);

__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(['name']);
__PACKAGE__->add_unique_constraint(['abbreviation']);

__PACKAGE__->validates(name => (presence=>1, length=>[2,18]));

__PACKAGE__->has_many(
  people =>
  'Example::Schema::Result::Person',
  { 'foreign.state_id' => 'self.id' }
);


1;

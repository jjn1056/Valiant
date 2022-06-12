package Example::Schema::Result::Todo;

use Example::Syntax;
use base 'Example::Schema::Result';

__PACKAGE__->table("todo");
__PACKAGE__->load_components(qw/Valiant::Result/);

__PACKAGE__->add_columns(
  id => { data_type => 'bigint', is_nullable => 0, is_auto_increment => 1 },  
  person_id => { data_type => 'integer', is_nullable => 0, is_foreign_key => 1 },
  title => { data_type => 'varchar', is_nullable => 0, size => 60 },
  status => { data_type => 'varchar', is_nullable => 0, default=>'active', size => 60 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to(
  person =>
  'Example::Schema::Result::Person',
  { 'foreign.id' => 'self.person_id' }
);

__PACKAGE__->validates(title => presence=>1, length=>[3,60]);
__PACKAGE__->validates(status => presence=>1, inclusion => [qw/active completed archived/] );

sub set_from_request($self, $request) {
  $self->set_columns_recursively($request->nested_params)
      ->insert_or_update;
}

1;

package Example::Schema::Result::Profile;

use Example::Syntax;
use base 'Example::Schema::Result';

__PACKAGE__->table("profile");
__PACKAGE__->load_components(qw/Valiant::Result/);

__PACKAGE__->add_columns(
  id => { data_type => 'bigint', is_nullable => 0, is_auto_increment => 1 },
  person_id => { data_type => 'integer', is_nullable => 0, is_foreign_key => 1 },
  state_id => { data_type => 'integer', is_nullable => 0, is_foreign_key => 1 },
  address => { data_type => 'varchar', is_nullable => 0, size => 48 },
  city => { data_type => 'varchar', is_nullable => 0, size => 32 },
  zip => { data_type => 'varchar', is_nullable => 0, size => 5 },
  birthday => { data_type => 'date', is_nullable => 1, datetime_undef_if_invalid => 1 },
  phone_number => { data_type => 'varchar', is_nullable => 1, size => 32 },
  registered => { data_type => 'boolean', is_nullable => 0 },
  status => { data_type => 'enum', is_nullable => 0, track_storage => 1 }
);

__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(['id','person_id']);

__PACKAGE__->belongs_to(
  state =>
  'Example::Schema::Result::State',
  { 'foreign.id' => 'self.state_id' }
);

__PACKAGE__->belongs_to(
  person =>
  'Example::Schema::Result::Person',
  { 'foreign.id' => 'self.person_id' }
);

__PACKAGE__->validates(address => (presence=>1, length=>[2,48]));
__PACKAGE__->validates(city => (presence=>1, length=>[2,32]));
__PACKAGE__->validates(zip => (presence=>1, format=>'zip'));
__PACKAGE__->validates(phone_number => (presence=>1, length=>[10,32]));
__PACKAGE__->validates(state_id => (presence=>1));
__PACKAGE__->validates(birthday => (
    date => {
      max => sub { pop->now->subtract(days=>2) }, 
      min => sub { pop->years_ago(30) }, 
    }
  )
);

__PACKAGE__->validates(status => (
    presence => 1,
    inclusion => [qw/pending active inactive/],
    with => {
      method => 'valid_status',
      on => 'update',
      if => 'is_column_changed', # This method defined by DBIx::Class::Row
    },
  )
);

sub valid_status($self, $attribute_name, $value, $opt) {
  my $old = $self->get_column_storage($attribute_name);
  if($old eq 'active') {
    $self->errors->add($attribute_name, "can't become pending once active", $opt) if $value eq 'pending';
  }
  if($old eq 'inactive') {
    $self->errors->add($attribute_name, "can't become pending once inactive", $opt) if $value eq 'pending';
  }
}


sub status_options($self) {
  return qw( pending active inactive );
}

1;

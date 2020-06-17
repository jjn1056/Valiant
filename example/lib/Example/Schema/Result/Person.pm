package Example::Schema::Result::Person;

use base 'Example::Schema::Result';

__PACKAGE__->table("person");
__PACKAGE__->load_components(qw/EncodedColumn Valiant::Result/);

__PACKAGE__->add_columns(
  id => { data_type => 'bigint', is_nullable => 0, is_auto_increment => 1 },
  username => { data_type => 'varchar', is_nullable => 0, size => 48 },
  first_name => { data_type => 'varchar', is_nullable => 0, size => 24 },
  last_name => { data_type => 'varchar', is_nullable => 0, size => 48 },
  password => {
    data_type => 'varchar',
    is_nullable => 0,
    size => 64,
    #    encode_column => 1,
    #    encode_class  => 'Digest',
    #    encode_args   => { algorithm => 'MD5', format => 'base64' },
    #    encode_check_method => 'check_password',
  },
);

__PACKAGE__->validates(username => presence=>1, length=>[3,24], format=>'alpha_numeric', unique=>1);
__PACKAGE__->validates(password => presence=>1, length=>[6,24], confirmation=>1, on=>'registration'); 
__PACKAGE__->validates(first_name => (presence=>1, length=>[2,24]));
__PACKAGE__->validates(last_name => (presence=>1, length=>[2,48]));

__PACKAGE__->validates(credit_cards => (presence=>1, result_set=>+{validations=>1, min=>2, max=>4}, on=>'profile' ));
__PACKAGE__->validates(person_roles => (presence=>1, result_set=>+{validations=>1, min=>1}, on=>'profile' ));
__PACKAGE__->validates(profile => (result_set=>+{validations=>1}, on=>'profile'  ));

__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(['username']);

__PACKAGE__->might_have(
  profile =>
  'Example::Schema::Result::Profile',
  { 'foreign.person_id' => 'self.id' }
);

__PACKAGE__->has_many(
  credit_cards =>
  'Example::Schema::Result::CreditCard',
  { 'foreign.person_id' => 'self.id' }
);

__PACKAGE__->has_many(
  person_roles =>
  'Example::Schema::Result::PersonRole',
  { 'foreign.person_id' => 'self.id' }
);

__PACKAGE__->many_to_many('roles' => 'person_roles', 'role');

sub registered {
  my $self = shift;
  return $self->validated && $self->valid;
}


1;

package Example::Schema::Result::Person;

use Example::Syntax;
use base 'Example::Schema::Result';

__PACKAGE__->table("person");

__PACKAGE__->add_columns(
  id => { data_type => 'bigint', is_nullable => 0, is_auto_increment => 1 },
  username => { data_type => 'varchar', is_nullable => 0, size => 48 },
  first_name => { data_type => 'varchar', is_nullable => 0, size => 24 },
  last_name => { data_type => 'varchar', is_nullable => 0, size => 48 },
  password => {
    data_type => 'varchar',
    is_nullable => 0,
    size => 64,
    bcrypt => 1,
  },
);

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

__PACKAGE__->has_many(
  todos =>
  'Example::Schema::Result::Todo',
  { 'foreign.person_id' => 'self.id' }
);

__PACKAGE__->validates(username => presence=>1, length=>[3,24], format=>'alpha_numeric', unique=>1);
__PACKAGE__->validates( password => (presence=>1, confirmation => 1,  on=>'create' ));
__PACKAGE__->validates( password => (confirmation => { 
    on => 'update',
    if => 'is_column_changed', # This method defined by DBIx::Class::Row
  }));

__PACKAGE__->validates(first_name => (presence=>1, length=>[2,24]));
__PACKAGE__->validates(last_name => (presence=>1, length=>[2,48]));

__PACKAGE__->validates(credit_cards => (set_size=>{min=>2, max=>4}, on=>'profile' ));
__PACKAGE__->accept_nested_for('credit_cards', +{allow_destroy=>1});

__PACKAGE__->validates(person_roles => (set_size=>{min=>1}, on=>'profile' ));
__PACKAGE__->accept_nested_for('person_roles', {allow_destroy=>1});

__PACKAGE__->accept_nested_for('profile');

sub available_states($self) {
  return $self->result_source->schema->resultset('State');
}

sub available_roles($self) {
  return $self->result_source->schema->resultset('Role');
}

sub register($self, $nested_params) {
  $self->set_columns_recursively($nested_params)
    ->set_columns_recursively(+{ person_roles=>[{role=>{label=>'user'}}] })
    ->insert_or_update;
  return $self;
}

sub authenticated($self) {
  return $self->username && $self->in_storage ? 1:0;
}

sub registered($self) {
  return $self->username &&
    $self->first_name &&
    $self->last_name &&
    $self->password ? 1:0;
}

1;

__END__

sub register($self, $model) {
  $self->first_name($model->first_name) if $model->has_first_name;
  $self->last_name($model->last_name) if $model->has_last_name;
  $self->password($model->password) if $model->has_password;
  $self->password_confirmation($model->password_confirmation) if $model->has_password_confirmation;
  $self->insert_or_update;
  return $self;
}

  my %pairs = $request->get_pairs(qw/
    first_name
    last_name
    password
    password_confirmation/);
  $self->set_columns_recursively(\%pairs)
    ->insert_or_update;
  

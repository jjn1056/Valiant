package Example;

use Catalyst;
use Moose;
use Valiant::I18N;
use Example::Base;

has user => (
  is => 'rw',
  required => 0,
  lazy => 1,
  builder => 'get_user_from_store',
  clearer => 'clear_user',
);

__PACKAGE__->setup_plugins([qw/
  Session
  Session::State::Cookie
  Session::Store::Cookie
  RedirectTo
  URI
  Errors
  StructuredParameters
/]);

__PACKAGE__->config(
  disable_component_resolution_regex_fallback => 1,
  'Plugin::Session' => { storage_secret_key => 'abc123' },
  'Model::Schema' => {
    traits => ['SchemaProxy'],
    schema_class => 'Example::Schema',
    connect_info => {
      dsn => "dbi:SQLite:dbname=@{[ __PACKAGE__->path_to('var','db.db') ]}",
    }
  },
);

__PACKAGE__->setup();

sub get_user_from_store($self) {
  my $id = $self->session->{user_id} // return;
  my $person = $self->model('Schema::Person')->find({id=>$id}) // return;
  return $person;
}

sub authenticate($self, $username='', $password='') {
  my $user = $self->model('Schema::Person')->authenticate($username, $password);
  $self->persist_user_to_session($user) unless $user->has_errors;
  return $user; 
}

sub persist_user_to_session ($self, $user) {
  $self->session->{user_id} = $user->id;
  $self->user($user);
}

sub logout($self) {
  $self->clear_user;
  $self->remove_user_from_session;
}

sub remove_user_from_session($self) {
  delete $self->session->{user_id};
}

__PACKAGE__->meta->make_immutable();

package Example;

use Catalyst;
use Moose;
use Example::Syntax;

__PACKAGE__->setup_plugins([qw/
  Session
  Session::State::Cookie
  Session::Store::Cookie
  RedirectTo
  URI
  Errors
  StructuredParameters
  ServeFile
  CSRFToken
/]);

__PACKAGE__->config(
  disable_component_resolution_regex_fallback => 1,
  using_frontend_proxy => 1,
  'Plugin::Session' => { storage_secret_key => 'abc123' },
  'Plugin::CSRFToken' => { auto_check =>1, default_secret => 'abc123' },
  'View::Components' => { components_class => 'Example::HTML::Components' },
  'View::Components::Layout' => { copyright => 2022 },
  'Model::Schema' => {
    traits => ['SchemaProxy'],
    schema_class => 'Example::Schema',
    connect_info => {
      dsn => "dbi:SQLite:dbname=@{[ __PACKAGE__->path_to('var','db.db') ]}",
    }
  },
);

__PACKAGE__->setup();

has user => (
  is => 'rw',
  lazy => 1,
  builder => 'get_user_from_session',
  clearer => 'clear_user',
);

# This should probably return an empty user rather than undef
sub get_user_from_session($self) {
  my $id = $self->session->{user_id} // return;
  my $person = $self->model('Schema::Person')->find_by_id($id) // return;
  return $person;
}

sub persist_user_to_session ($self, $user) {
  $self->session->{user_id} = $user->id;
}

sub remove_user_from_session($self) {
  delete $self->session->{user_id};
}

sub authenticate($self, $username='', $password='') {
  my $user = $self->model('Schema::Person')->authenticate($username, $password);
  $self->set_user($user) if $user->no_errors;
  return $user; 
}

sub set_user ($self, $user) {
  $self->persist_user_to_session($user);
  $self->user($user);
}

sub logout($self) {
  $self->clear_user;
  $self->remove_user_from_session;
}

__PACKAGE__->meta->make_immutable();

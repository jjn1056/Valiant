package Example;

use Catalyst;
use Valiant::I18N;

__PACKAGE__->setup_plugins([qw/
  Authentication
  Session
  Session::State::Cookie
  Session::Store::Cookie
  RedirectTo
  URI
/]);

__PACKAGE__->config(
  disable_component_resolution_regex_fallback => 1,
  'Plugin::Session' => { storage_secret_key => 'abc123' },
  'Plugin::Authentication' => {
    default_realm => 'members',
    realms => {
      members => {
        credential => {
          class => 'Password',
          password_field => 'password',
          # password_type => 'self_check'
          password_type => 'clear',
        },
        store => {
          class => 'DBIx::Class',
          user_model => 'Schema::Person',
        },
      },
    },
  },
  'Model::Schema' => {
    traits => ['SchemaProxy'],
    schema_class => 'Example::Schema',
    connect_info => {
      dsn => 'dbi:Pg:dbname=jnapiorkowski',
      user => 'postgres',
      password => ''
    }
  },
);

__PACKAGE__->setup();
__PACKAGE__->meta->make_immutable();


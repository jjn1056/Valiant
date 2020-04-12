package Example;

use Catalyst;
use Valiant::I18N;

__PACKAGE__->setup_plugins([qw/
  Authentication
  Session
  Session::State::Cookie
  Session::Store::Cookie
  RedirectTo
  InjectionHelpers
  URI
/]);

__PACKAGE__->config(
  disable_component_resolution_regex_fallback => 1,
  'Plugin::Session' => { storage_secret_key => 'abc123' },
  'Plugin::Authentication' => {
    default_realm => 'members',
    members => {
      credential => {
        class => 'Password',
        password_field => 'password',
        password_type => 'clear'
      },
      store => {
        class => 'Minimal',
        users => {
          john => { password=>'green59' },
          mark => { password=>'nowisthetime' },
        }
      },
    },
  },
  'Model::Schema' => {
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


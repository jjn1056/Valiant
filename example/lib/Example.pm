package Example;

use Catalyst;
use Valiant::I18N;
use feature ':5.16';

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

sub user {
  my ($c) = @_;
  return $c->{__user} ||= do {
    my $id = $c->session->{user_id} // return;
    my $person = $c->model('Schema::Person')->find({id=>$id}) // return;
  };
}

__PACKAGE__->meta->make_immutable();

package MyApp::Model::Schema;

use Moose;
extends 'Catalyst::Model::DBIC::Schema';

__PACKAGE__->meta->make_immutable();
__PACKAGE__->config(
  connect_info => { dsn => $ENV{DBI_DSN} },
  traits => ['SchemaProxy'],
  schema_class => 'MyApp::Schema',
  querylog_args => { passthrough => 1 },
);

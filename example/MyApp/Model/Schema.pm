package MyApp::Model::Schema;

use Moose;

__PACKAGE__->meta->make_immutable();

__END__
#extends 'Catalyst::Model::DBIC::Schema';

__PACKAGE__->config(
  traits => ['SchemaProxy'],
  schema_class => 'MyApp::Schema',
  querylog_args => { passthrough => 1 },
);


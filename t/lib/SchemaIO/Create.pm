package SchemaIO::Create;

use base 'DBIO::Schema';

use strict;
use warnings;

our $VERSION = 1;

__PACKAGE__->load_namespaces(
  default_resultset_class => "+SchemaIO::DefaultRS");



1;

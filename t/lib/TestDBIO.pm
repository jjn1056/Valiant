package TestDBIO;

use strict;
use warnings;

# Minimal stand-in for the one Test::DBIx::Class feature the dbic test
# suite uses: a 'Schema' function bound to a connected, deployed,
# in-memory SQLite schema.
#
#   use TestDBIO -schema_class => 'ExampleIO::Schema';
#   use TestDBIO -schema_class => 'ExampleIO::Schema', -async => 'immediate';

my $schema;

sub import {
  my ($class, %opts) = @_;
  my $caller = caller;
  my $schema_class = $opts{'-schema_class'}
    or die "TestDBIO requires -schema_class";

  eval "require $schema_class; 1" or die $@;

  my %attrs = (RaiseError => 1);
  $attrs{async} = $opts{'-async'} if $opts{'-async'};

  $schema = $schema_class->connect('dbi:SQLite:dbname=:memory:', '', '', \%attrs);
  $schema->deploy;

  no strict 'refs';
  *{"${caller}::Schema"} = sub { $schema };
}

1;

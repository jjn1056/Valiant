package Example::Schema;

use base 'DBIx::Class::Schema';

use strict;
use warnings;
use SQL::Translator;
use SQL::Translator::Diff;

our $VERSION = 1;

__PACKAGE__->load_components(qw/
  Helper::Schema::QuoteNames
  Helper::Schema::DidYouMean
  Helper::Schema::DateTime/);

__PACKAGE__->load_namespaces(
  default_resultset_class => "DefaultRS");

sub diff {
  my $schema = shift;

  my $dbic = SQL::Translator->new(
   producer => 'PostgreSQL',
   parser => 'SQL::Translator::Parser::DBIx::Class',
   parser_args => { dbic_schema => $schema,},
  );

  my $database_current  =  SQL::Translator->new(
      producer => 'PostgreSQL',
      parser => 'DBI',
      parser_args => { dbh => $schema->storage->dbh },
  );

  warn $dbic->translate;
  warn $database_current->translate;

  warn SQL::Translator::Diff->new({
    output_db     => 'PostgreSQL',
    target_schema => $dbic->schema,
    source_schema => $database_current->schema,
  })->compute_differences->produce_diff_sql;
}

1;

# DBI_DSN=dbi:Pg:dbname=jnapiorkowski perl  -I ../lib/ -I. Liminal/Server.pm
# DBI_DSN=dbi:Pg:dbname=jnapiorkowski perl -I ../lib/ -I. -e 'use Liminal; warn Liminal->model("Schema")->deployment_statements;'

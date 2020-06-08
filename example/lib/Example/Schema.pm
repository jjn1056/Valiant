package Example::Schema;

use base 'DBIx::Class::Schema';

use strict;
use warnings;
use SQL::Translator;
use SQL::Translator::Diff;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use App::Sqitch::Command::add;

our $VERSION = 1;

__PACKAGE__->load_components(qw/
  Helper::Schema::QuoteNames
  Helper::Schema::DidYouMean
  Helper::Schema::DateTime/);

__PACKAGE__->load_namespaces(
  default_resultset_class => "DefaultRS");

sub diff2 {
  my ($schema) = @_;

  my $source_schema = do {
    my $t = SQL::Translator->new(
     no_comments => 1, # comment has timestamp so that breaks the md5 checksum
     parser => 'SQL::Translator::Parser::DBIx::Class',
     parser_args => { dbic_schema => $schema },
    );
    $t->translate;
    $t->schema;
  };

  my $target_schema = do {
    my $t = SQL::Translator->new(
      no_comments => 1, # comment has timestamp so that breaks the md5 checksum
      parser => 'DBI',
      parser_args => {
          dbh => $schema->storage->dbh,
      },
    );
    $t->translate;
    $t->schema;
  };

  use Devel::Dwarn;
  Dwarn $target_schema;

  my $diff = SQL::Translator::Diff->new({
    output_db => 'PostgreSQL',
    ignore_constraint_names => 1,
    source_schema => $source_schema,
    target_schema => $target_schema,
  })->compute_differences->produce_diff_sql;

  warn $diff;

}

sub diff {
  my ($schema, $dir) = @_;

  my $current_ddl = SQL::Translator->new(
   no_comments => 1, # comment has timestamp so that breaks the md5 checksum
   producer => 'PostgreSQL',
   parser => 'SQL::Translator::Parser::DBIx::Class',
   parser_args => { dbic_schema => $schema },
  )->translate;

  warn $current_ddl;;

  my $current_checksum = md5_hex($current_ddl);

  my ($last_created_schema) =  map { $_ } sort { $b cmp $a } $dir->children;
  if($last_created_schema) {
    my ($last_checksum) = ("$last_created_schema"=~m/\.(.+?)\.sql$/);
    if($current_checksum eq $last_checksum) {
      warn "No Change!";
      #return;
    }
  }

  # Save the DDL since there's a change or its the first one.
  my @d = localtime;
  my $file = $dir->file(sprintf "%02d-%02d-%02d@%02d:%02d:%02d.%s.sql", $d[5]+1900,$d[4]+1,@d[3,2,1,0], $current_checksum);
  $file->spew($current_ddl);

  # Generate a Diff
  my $last_ddl = $last_created_schema->slurp;
  my $schema_last = SQL::Translator->new(
    parser => 'PostgreSQL',
    data => $last_ddl,
  )->translate;

  my $schema_current = SQL::Translator->new(
    parser => 'PostgreSQL',
    data => $current_ddl,
  )->translate;

  my $deploy_diff = SQL::Translator::Diff->new({
    output_db => 'PostgreSQL',
    ignore_constraint_names => 1,
    target_schema => $schema_current,
    source_schema => $schema_last,
  })->compute_differences->produce_diff_sql;

  my $revert_diff = SQL::Translator::Diff->new({
    output_db => 'PostgreSQL',
    ignore_constraint_names => 1,
    target_schema => $schema_last,
    source_schema => $schema_current,
  })->compute_differences->produce_diff_sql;

  use App::Sqitch;
  use App::Sqitch::Config;
  use App::Sqitch::Command::add;

  my $change_name = 'test'.time;
  my $path = $dir->parent->file('sqitch.conf');
  local $ENV{SQITCH_CONFIG} = $path;

  my $cmd = App::Sqitch::Command::add->new(
    sqitch => App::Sqitch->new(
      config => App::Sqitch::Config->new()
    ),
    change_name => $change_name,
    note => ['te111sts testsetst'],
    template_directory => $dir,
  );

  $cmd->execute;

  my $deploy_script = $dir->parent->subdir('deploy')->file("${change_name}.sql")->slurp;
  $deploy_script=~s/^\-\- XXX Add DDLs here\.$/$deploy_diff/smg;
  $dir->parent->subdir('deploy')->file("${change_name}.sql")->spew($deploy_script);

  my $revert_script = $dir->parent->subdir('revert')->file("${change_name}.sql")->slurp;
  $revert_script=~s/^\-\- XXX Add DDLs here\.$/$revert_diff/smg;
  $dir->parent->subdir('revert')->file("${change_name}.sql")->spew($revert_script);

}

1;

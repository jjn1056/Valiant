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

# cd to example
# perl -Ilib -I ../lib/ -MExample -e 'Example->model("Schema")->create_migration(Example->path_to(), "test_migration")' 
#
sub create_migration {
  my ($schema, $dir, $change) = @_;
  $change = 'test' unless defined $change;

  my $current_ddl = SQL::Translator->new(
   no_comments => 1, # comment has timestamp so that breaks the md5 checksum
   producer => 'PostgreSQL',
   parser => 'SQL::Translator::Parser::DBIx::Class',
   parser_args => { dbic_schema => $schema },
  )->translate;

  my $current_checksum = md5_hex($current_ddl);

  my ($last_created_schema) =  map { $_ } sort { $b cmp $a } $dir->subdir('sql','schemas')->children;
  if($last_created_schema) {
    my ($last_checksum) = ("$last_created_schema"=~m/\.(.+?)\.sql$/);
    if($current_checksum eq $last_checksum) {
      warn "No Change!";
      return;
    }
  }

  # Save the DDL since there's a change or its the first one.
  my @d = localtime;
  my $file = $dir->subdir('sql','schemas')
    ->file(sprintf "%02d-%02d-%02d@%02d:%02d:%02d.%s.sql", $d[5]+1900,$d[4]+1,@d[3,2,1,0], $current_checksum);
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

  my $change_name = $change.'_'.time;
  my $path = $dir->file('sqitch.conf');
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

  my $deploy_script = $dir->subdir('sql','deploy')->file("${change_name}.sql")->slurp;
  $deploy_script=~s/^\-\- XXX Add DDLs here\.$/$deploy_diff/smg;
  $dir->subdir('sql','deploy')->file("${change_name}.sql")->spew($deploy_script);

  my $revert_script = $dir->subdir('sql','revert')->file("${change_name}.sql")->slurp;
  $revert_script=~s/^\-\- XXX Add DDLs here\.$/$revert_diff/smg;
  $dir->subdir('sql','revert')->file("${change_name}.sql")->spew($revert_script);

}

1;

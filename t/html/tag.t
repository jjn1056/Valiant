use Test::Most;
use Valiant::HTML::Tag;

{
  ok my $tag = Valiant::HTML::Tag->new(
    model_name => 'person',
    method_name => 'name',
    view => 1,
  );

  use Devel::Dwarn;
  Dwarn $tag->options;
}

{
  ok my $tag = Valiant::HTML::Tag->new(
    model_name => 'person[]',
    method_name => 'name',
    view => 1,
    options => +{ model=>111 },
  );

  use Devel::Dwarn;
  Dwarn $tag->options;
  Dwarn $tag;
  warn $tag->model;
    Dwarn $tag;

}


done_testing;

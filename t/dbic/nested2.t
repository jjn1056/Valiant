use Test::Most;
use Test::Lib;
use Test::DBIx::Class
  -schema_class => 'Schema::Nested';

{
  ok my $top = Schema
    ->resultset('XTop')
    ->create({
      top_value => 'aaaaaa',
      middle => {
        middle_value => 'bbbbbb',
        bottom => {
          bottom_value => 'cccccc',
        },
      },
    });

  ok $top->valid;
}

{
  ok my $top = Schema
    ->resultset('XTop')
    ->create({
      top_value => 'aaaaa',
      middle => {
        middle_value => 'bbbbb',
        bottom => {
          bottom_value => 'ccc',
        },
      },
    });

  ok $top->invalid;
}

done_testing;

__END__

  use Devel::Dwarn;
  Dwarn +{ $top->errors->to_hash(full_messages=>1) };


use Test::Most;
use Valiant::Errors;

ok my $e = Valiant::Errors->new(fields=>[qw(name age addresses emails)]);

ok $e->add(name => 'Too long');
ok $e->delete('name');
ok $e->add(name => 'Too long');
ok $e->add(name => 'Too Short');
ok $e->clear;
ok $e->add(name => 'Too long');
ok $e->add(name => 'Too Short');
ok $e->unshift(name => 'Very Important!');
ok $e->added(name => 'Very Important!');
ok $e->add(age => 25);
is_deeply [sort { $a cmp $b } $e->keys], ['age','name'];
is $e->size_for('name'), 3;
is $e->size, 4;
ok not $e->empty;


use Devel::Dwarn;
Dwarn $e;

$e->each(sub {
  my ($field, $value) = @_;
  warn "Field $field has error: $value";
});

warn $e->full_message(name=>'Too Short');


done_testing;

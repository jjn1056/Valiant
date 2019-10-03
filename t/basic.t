use Test::Most;

ok 1;

{
  package A;

  use Moo;

  my $a = '';
  sub a {
    my ($self, $value) = @_;
    no strict 'refs';
    my $class = ref $self;
    return ${"${class}::a"} ||= $value;
  }

  package B;

  use Moo;
  extends 'A';
}

my $a = A->new;
my $b = B->new;

$a->a('B');

warn $a->a || 'na';
warn $b->a || 'na';

$b->a('C');

warn $a->a || 'na';
warn $b->a || 'na';

done_testing;

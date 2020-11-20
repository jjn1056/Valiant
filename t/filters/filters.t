use Test::Lib;
use Test::Most;

{
  package Local::Test::Filter::Foo;

  use Moo;
  has ['a','b'] => (is=>'ro');

  with 'Valiant::Filter';

  sub filter {
    my ($self, $class, $attrs) = @_;
    $attrs->{name} = uc $attrs->{name};
    return $attrs;
  }

  package Local::Test::User;

  use Moo;

  with 'Valiant::Util::Ancestors',
    'Valiant::Filterable';

  has 'name' => (is=>'ro', required=>1);

  __PACKAGE__->filters_with(sub {
    my ($class, $attrs, $opts) = @_;
    $attrs = +{
      map {
        my $value = $attrs->{$_};
        $value =~ s/^\s+|\s+$//g;
        $_ => $value;
      } keys %$attrs
    };
    $attrs->{name} = "$opts->{a}$attrs->{name}$opts->{b}";
    return $attrs;
  }, a=>1, b=>2);

  __PACKAGE__->filters_with(Foo => (a=>1,b=>2));
}

my $user = Local::Test::User->new(name=>'  john ');

is $user->name, '1JOHN2';


done_testing;

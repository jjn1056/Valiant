use Test::Most;

{
  package Local::Profile;

  use Moo;
  use Valiant::Params;

  has email => (is=>'ro', required=>1, param=>1);
  has age => (is=>'ro', required=>1, param=>1);

  package Local::Person;

  use Moo;
  use Valiant::Params;

  has formal_name => (is=>'ro', required=>1, param=>[name=>'formal-name']);
  has user_name => (is=>'ro', required=>1, param=>[name=>'user-name']);
 
  has profile => (
    is=>'ro',
    param => { expand => 1 },
    coerce => sub { ref($_[0])||'' eq 'HASH' ? Local::Profile->new(request=>$_[0]) : $_[0] },
  );

}

my %request = (
  'formal-name' => 'John Napiorkowski',
  'user-name' => 'jjn',
  'profile' => +{
    email => 'jjn@gmail.com',
    age => 52,
  },
);

ok my $person = Local::Person->new(request=>\%request);

use Devel::Dwarn;
Dwarn $person;
Dwarn $person->profile->params_as_hash;

is_deeply +{ $person->params_as_hash },{
    formal_name => 'John Napiorkowski',
    user_name => 'jjn',
  };

done_testing;

__END__



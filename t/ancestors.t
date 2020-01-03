use Test::Lib;
use Test::Most;
use Retiree;

ok my $retiree = Retiree->new(
  name=>'B',
  age=>4,
  retirement_date=>'2020');

ok !$retiree->validate;
is_deeply +{ $retiree->errors->to_hash(full_messages=>1) },
  {
    _base => [
      "Just Bad",
      "Failed TestRole",
    ],
    age => [
      "Age Too Young",
      "Age Logged a 4",
    ],
    name => [
      "Name Too Short",
      "Name Too Custom: 123",
      "Name Logged a B",
      "Name is too short (minimum is 3 characters)",
      "Name just weird name",
      "Name Is Invalid",
      "Name Just Bad",
    ],
    retirement_date => [
      "Retires On Failed Retiree",
    ],     
  };

#use Devel::Dwarn;
#Dwarn +{ $retiree->errors->to_hash(full_messages=>1) };

done_testing;

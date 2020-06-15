use Test::Most;
use DateTime;
use DateTime::Format::Strptime;
use Valiant::Validator::Date;

#ok my $strp = DateTime::Format::Strptime->new('%Y-%m-%d');

{
  package Local::Test::Date;

  use Moo;
  use Valiant::Validations;

  has birthday => (is=>'ro');

  validates birthday => (
    date => {
      min => sub { pop->years_ago(120) }, # Oldest person I think...
      max => sub { pop->now },
      with => \&my_special,
    },
  );

  sub my_special_method {
    my ($self, $dt, $type) = @_;
  }
}

ok my $min = DateTime->now->subtract(years=>120)->strftime($Valiant::Validator::Date::_pattern);
ok my $max = DateTime->now->strftime($Valiant::Validator::Date::_pattern);

use Devel::Dwarn;
Dwarn +{  Local::Test::Date->named_validators };

{
  ok my $object = Local::Test::Date->new(birthday=>DateTime->now->subtract(years=>5));
  ok $object->validate->valid; 
}

{
  ok my $object = Local::Test::Date->new(birthday=>DateTime->now->subtract(years=>500));
  ok $object->validate->invalid;
  is_deeply +{ $object->errors->to_hash(full_messages=>1) },
    {
      'birthday' => [
        "Birthday chosen date can't be earlier than $min",
      ],
    };
}


done_testing;

__END__

{
  ok my $object = Local::Test::Date->new(active=>0, flag=>1);
  ok $object->validate->invalid; 
  is_deeply +{ $object->errors->to_hash(full_messages=>1) },
    {
      'active' => [
        'Active must be a true value',
      ],
      'flag' => [
        'Flag must be a false value',
      ]

    };
}


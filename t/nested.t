use Test::Most;

{
  package Local::Person;

  use Moo;
  use Valiant::Params;

  has 'first_name' => (is=>'ro', predicate=>1);
  has 'last_name' => (is=>'ro', predicate=>1);
  has 'user_name' => (is=>'ro', predicate=>1);
  has 'profile' => (is=>'ro', predicate=>1);

  nested 'profile' 
    type => 'Object'

}

my $person = Local::Person->new(
  request => +{name=>'john', email=>'jjn1056@gmail.com', arg1=>['1','2'], arg3=>'3'},
  age => 11,
);

is_deeply +{ $person->params_info },
  {
    age => {
      multi => 0,
      name => "age",
    },
    arg1 => {
      multi => 1,
      name => "arg1",
    },
    arg2 => {
      multi => 0,
      name => "arg2",
    },
    arg3 => {
      multi => 0,
      name => "arg3",
    },
    email => {
      multi => 0,
      name => "email",
    },
    name => {
      multi => 1,
      name => "name",
    },
    phone => {
      multi => 0,
      name => "phone",
    },
  };

is_deeply [sort($person->param_keys)], [  sort "arg3", "email", "arg1", "name"];


is_deeply $person->arg1, [1,2];
is $person->arg3, 3;
is_deeply $person->name, ['john'];
is $person->email, 'jjn1056@gmail.com';

is $person->get_param('email'), 'jjn1056@gmail.com';
ok $person->param_exists('email');
ok !$person->param_exists('arg2');

is_deeply +{ $person->params_as_hash },{
    arg1 => [
      1,
      2,
    ],
    arg3 => 3,
    email => "jjn1056\@gmail.com",
    name => [
      "john",
    ],
  };

done_testing;

__END__



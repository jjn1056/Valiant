use Test::Most;

{
  package Local::Person;

  use Moo;
  use Valiant::Params;

  has [qw/age email phone arg1 arg2 arg3/] => (is=>'ro', predicate=>1);
  has 'name' => (is=>'ro', predicate=>1, required=>1);

  # If param is named then the incoming is permitted to have that value.  It can be option (if you want required set that on the attribute)
  param 'name',
    name => 'given-name', # default is use the attribute name
    multi => 1; # this is the default.   it means will allow scalar only.   if 1 then forces to arrayref (or acceptsref)

  param [qw/age email phone/]; # This form allows no options.

  params 'arg1', +{multi=>1}, 'arg2', 'arg3'; # This form does
}

my $person = Local::Person->new(
  request => +{'given-name'=>'john', email=>'jjn1056@gmail.com', arg1=>['1','2'], arg3=>'3'},
  age => 11,
);

is_deeply +{ $person->params_info },
  {
    age => {
      expand => {
        preserve_index => 0,
      },
      multi => 0,
      name => "age",
    },
    arg1 => {
      expand => {
        preserve_index => 0,
      },
      multi => {
        limit => 10000,
      },
      name => "arg1",
    },
    arg2 => {
      expand => {
        preserve_index => 0,
      },
      multi => 0,
      name => "arg2",
    },
    arg3 => {
      expand => {
        preserve_index => 0,
      },
      multi => 0,
      name => "arg3",
    },
    email => {
      expand => {
        preserve_index => 0,
      },
      multi => 0,
      name => "email",
    },
    name => {
      expand => {
        preserve_index => 0,
      },
      multi => {
        limit => 10000,
      },
      name => "given-name",
    },
    phone => {
      expand => {
        preserve_index => 0,
      },
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



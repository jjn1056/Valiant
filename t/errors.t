use Test::Most;

{
  package Local::Object::User;

  use Valiant::Errors;
  use Valiant::I18N;
  use Moo;

  with 'Valiant::Naming';

  has 'errors' => (
    is => 'ro',
    init_arg => undef,
    lazy => 1,
    default => sub { Valiant::Errors->new(object=>shift) },
  );

  sub validate {
    my $self = shift;
    $self->errors->add('test01', _t('testerror'), +{message=>'another test error1'});
    $self->errors->add('test01', _t('invalid') );
    $self->errors->add('test02', 'test error');
    $self->errors->add(undef, 'test model error');
  }

  sub read_attribute_for_validation {
    my $self = shift;
    return shift;
  }

  sub human_attribute_name {
    my ($self, $attribute) = @_;
    return $attribute;
  }

  sub ancestors { }
}

ok my $user1 = Local::Object::User->new;
ok my $user2 = Local::Object::User->new;

$user1->validate;
$user2->validate;

is_deeply +{ $user1->errors->to_hash }, +{
    "*" => [
      "test model error",
    ],
    test01 => [
      "another test error1",
      "Is Invalid",
    ],
    test02 => [
      "test error",
    ],
  };

is_deeply [ $user1->errors->model_errors_array ], [
  "test model error",
];

$user1->errors->merge($user2->errors);
is_deeply +{ $user1->errors->to_hash }, +{
    "*" => [
      "test model error",
      "test model error",
    ],
    test01 => [
      "another test error1",
      "Is Invalid",
      "another test error1",
      "Is Invalid",
    ],
    test02 => [
      "test error",
      "test error",
    ],
  };

ok $user1->errors->any(sub {
  ${\$_->type} eq 'invalid';
  });

ok ! $user1->errors->any(sub {
  ${\$_->type} eq 'indvalid';
  });

is_deeply [$user1->errors->full_messages_for('test01')], [
    "test01 another test error1",
    "test01 Is Invalid",
    "test01 another test error1",
    "test01 Is Invalid",
  ];


$user1->errors->delete('test01');
is_deeply +{ $user1->errors->to_hash }, +{
    "*" => [
      "test model error",
      "test model error",
    ],
    test02 => [
      "test error",
      "test error",
    ],
  };

ok $user2->errors->of_kind('test01', "Is Invalid");
ok ! $user2->errors->of_kind('test0x', "Is Invalid");

is_deeply [$user2->errors->full_messages], [
    "test01 another test error1",
    "test01 Is Invalid",
    "test02 test error",
    "test model error",
  ];

done_testing;

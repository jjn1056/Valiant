use Test::Most;
use Test::Lib;
use Test::DBIx::Class
  -schema_class => 'Schema::Nested';

# Create Tests.  Tests that follow into a nested relationship via an initial
# create

# One to One. When creating a record and nesting into a 1-1 relationship we
# always create a new related record UNLESS there is a match PK or UNIQUE field
# present in the nested related data, if there is a match like that then we instead
# do a FIND and update that found record with the new FK info and any updated fields
# if valid.  If the find fails for unique or PK we go ahead and create anyway.

{
  # Just successfully create a nested relationship.
  ok my $one = Schema
    ->resultset('OneOne')
    ->create({
      value => 'test',
      one => { value => 'hello'},
    }), 'created fixture';
  
  ok $one->valid;
  ok $one->in_storage;
  ok $one->one->in_storage;

  # do a good update
  $one->update({
    value => 'test2',
    one => { value => 'test3' }
  });

  ok $one->valid;
  ok $one->in_storage;
  ok $one->one->in_storage;

  # do a bad update
  $one->update({
    value => 't',
    one => { value => 't' }
  });

  ok $one->invalid;
  is_deeply +{$one->errors->to_hash(full_messages=>1)}, +{
    value => [
      "Value is too short (minimum is 3 characters)",
    ],
    one => [
      "One Is Invalid",
    ],
    "one.value" => [
      "One Value is too short (minimum is 2 characters)",
    ],
  }, 'Got expected errors';
}

{
  # Fail in the parent
  ok my $one = Schema
    ->resultset('OneOne')
    ->create({
      value => 't', # to short
      one => { value => 'hhhhhhhhh'}, 
    }), 'created fixture';
  
  ok $one->invalid;
  ok !$one->in_storage;
  ok !$one->one->in_storage;

  is_deeply +{$one->errors->to_hash(full_messages=>1)}, +{
    value => [
      "Value is too short (minimum is 3 characters)",
    ],
  }, 'Got expected errors';

  $one->value("ffffffff");
  $one->insert;
  
  ok $one->valid;
  ok $one->in_storage;
  ok $one->one->in_storage;
}

{
  # Fail in the nested rel
  ok my $one = Schema
    ->resultset('OneOne')
    ->create({
      value => 'test',
      one => { value => 'h'}, # to short
    }), 'created fixture';
  
  ok $one->invalid;
  ok !$one->in_storage;
  ok !$one->one->in_storage;

  is_deeply +{$one->errors->to_hash(full_messages=>1)}, +{
    one => [
      "One Is Invalid",
    ],
    "one.value" => [
      "One Value is too short (minimum is 2 characters)",
    ],
  }, 'Got expected errors';

  $one->one->value("ffffffff");
  $one->insert;
  
  ok $one->valid;
  ok $one->in_storage;
  ok $one->one->in_storage;
}

{
  #test bulk
  my $rs = Schema
    ->resultset('OneOne')
    ->search({},{cache=>1});
  $rs->update_all({value=>'h'});

  while(my $result = $rs->next) {
    ok $result->invalid;
    is $result->value, 'h';
    is_deeply +{$result->errors->to_hash(full_messages=>1)}, +{
      value => [
        "Value is too short (minimum is 3 characters)",
      ],
    }, 'Got expected errors';
  }
}

{
  #test bulk nested 
  my $rs = Schema
    ->resultset('OneOne')
    ->search({},{cache=>1});
  $rs->update_all({one => {value=>'h'}});

  while(my $result = $rs->next) {
    ok $result->invalid;
    is $result->one->value, 'h';
    is_deeply +{$result->errors->to_hash(full_messages=>1)}, +{
      one => [
        "One Is Invalid",
      ],
      "one.value" => [
        "One Value is too short (minimum is 2 characters)",
      ],
    }, 'Got expected errors';
  }
}

{
  # test double nested and make sure we can insert all the way down
  ok my $one = Schema
    ->resultset('OneOne')
    ->create({
      value => 'test01',
      one => {
        value => 'hhh',
        might => { value => 'mighth' }
      },
    }), 'created fixture';

  ok $one->valid;
  ok $one->in_storage;
  ok $one->one->in_storage;
  ok $one->one->might->in_storage;
}

{
  # test double nested and make sure we can insert all the way down
  ok my $one = Schema
    ->resultset('OneOne')
    ->create({
      value => 'test02',
      one => {
        value => 'hhh2',
        might => { value => 'mightxxxxhxxxxxxxxxxxxx' }
      },
    }), 'created fixture';

  ok $one->invalid;
  is_deeply +{$one->errors->to_hash(full_messages=>1)}, +{
    one => [
      "One Is Invalid",
    ],
    "one.might" => [
      "One Might Is Invalid",
    ],
    "one.might.value" => [
      "One Might Value is too long (maximum is 8 characters)",
    ],
  }, 'Got expected errors';

  $one->one->might->value('ff');

  $one->insert;
  ok $one->valid;

  {
    # deep update
    ok my $result = Schema->resultset('OneOne')->find($one->id);
    $result->update(
      {
        value =>'test04',
        one => {
          value => 'test05',
          might => {
            value => 'test06',
          },
        },
      }
    );
   
    $one->insert;
    ok $one->valid;

    ok my $copy = $one->get_from_storage;
    is $copy->value, 'test04';
    is $copy->one->value, 'test05';
    is $copy->one->might->value, 'test06';
  }

  #  ok my $steal_rel = Schema
  #    ->resultset('OneOne')
  #    ->create({
  #      value => 'test10',
  #      one => {
  #        value => 'test05',
  #      },
  #    }), 'created fixture';

}

{
  # reject_if  tests
  ok my $one = Schema
    ->resultset('OneOne')
    ->create({
      value => 'test12',
      one => {
        value => 'test13',
        might => { value => 'test14' }
      },
    }), 'created fixture';

  ok $one->valid;
  ok $one->one;
  ok !$one->one->might;

}

done_testing;

__END__

  use Devel::Dwarn;
  Dwarn +{$one->errors->to_hash(full_messages=>1)};

# also terset from oneone to one (we expect one to exist so that should always be an update)

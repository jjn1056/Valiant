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

# If one wants to replace a might have with a new record you should first delete the
# exising record.

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

  # good update
  $one->update({
    value => 'ttttt',
    one => { value => 'ttttt' }
  });

  ok $one->valid;
  $one->discard_changes;
  is $one->value, 'ttttt';
  is $one->one->value, 'ttttt';
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

  $one->discard_changes;

  is $one->value, 'test01';
  is $one->one->value, 'hhh';
  is $one->one->might->value, 'mighth';

  $one->update({
    one => {
      might => { value => 'xtest01' },
    },
  });

  ok $one->valid;
  $one->discard_changes;
  is $one->one->might->value, 'xtest01';

  $one->one->might->value('xtest02');
  $one->update;
  ok $one->valid;
  $one->discard_changes;
  is $one->one->might->value, 'xtest02';

  $one->one->might->value('ggggfffffdddd too long...');
  $one->update;
  
  ok $one->invalid;
  is $one->one->might->value, 'ggggfffffdddd too long...';
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

  is_deeply +{$one->one->might->errors->to_hash(full_messages=>1)}, +{
    "value" => [
      "Value is too long (maximum is 8 characters)",
    ],
  }, 'Got expected errors';

  $one->one->might->value('ok');
  $one->update;
  ok $one->valid;
  $one->discard_changes;
  is $one->one->might->value, 'ok';
  is $one->one->value, 'hhh';
  is $one->value, 'test01';
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

# Lets do one or two reverse to stress belongs to.  Here's
# a bunch that shoud all always pass.
#

{
  my $might = Schema
    ->resultset('Might')
    ->create({
      value => 'might01',
      one => {
        value => 'might02',
        oneone => {
          value => 'might03',
        },
      },
    });

  ok $might->valid;
  ok $might->in_storage;
  ok $might->one->in_storage;
  ok $might->one->oneone->in_storage;

  $might->update({
    value => 'might05',
    one => {
      oneone => {
        value => 'might04'
      },
    },
  });
 
  ok $might->valid;
  is $might->value, 'might05';
  is $might->one->value, 'might02';
  is $might->one->oneone->value, 'might04';
  
  $might->discard_changes; # reload
  
  is $might->value, 'might05';
  is $might->one->value, 'might02';
  is $might->one->oneone->value, 'might04';

  $might->value('might06');
  $might->one->value('might07');
  $might->one->oneone->value('might08');
  $might->update;

  ok $might->valid;
  $might->discard_changes; # reload
  
  is $might->value, 'might06';
  is $might->one->value, 'might07';
  is $might->one->oneone->value, 'might08';

  $might->value('might09');
  $might->one->oneone->value('might10');
  $might->update;
  ok $might->valid;

  $might->discard_changes; # reload
  
  is $might->value, 'might09';
  is $might->one->value, 'might07';
  is $might->one->oneone->value, 'might10';
}

done_testing;

__END__

  use Devel::Dwarn;
  Dwarn +{$one->errors->to_hash(full_messages=>1)};

# also terset from oneone to one (we expect one to exist so that should always be an update)

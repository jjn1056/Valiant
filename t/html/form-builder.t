use Test::Most;
use Valiant::HTML::FormBuilder;
use DateTime;
use Valiant::HTML::Util::Collection;
use Valiant::HTML::FormTags 'option_tag';

{
  package Local::Role;

  use Moo;
  use Valiant::Validations;

  has ['id', 'label'] => (is=>'ro', required=>1);

  package Local::State;

  use Moo;
  use Valiant::Validations;

  has ['id', 'name'] => (is=>'ro', required=>1);

  package Local::Profile;

  use Moo;
  use Valiant::Validations;

  has address => (is=>'ro');
  has zip => (is=>'ro');

  validates address => (
    length => {
      maximum => 40,
      minimum => 3,
    },
  );

  package Local::CreditCard;

  use Moo;
  use Valiant::Validations;

  has ['number', 'expiration'] => (is=>'ro', required=>1);

  validates number => (presence=>1, length=>[13,20] );
  validates expiration => (presence=>1, date=>'is_future' ); 

  package Local::Person;

  use Moo;
  use Valiant::Validations;
  use Valiant::Filters;

  has first_name => (is=>'ro');
  has last_name => (is=>'ro');
  has status => (is=>'rw');
  has type => (is=>'rw');
  has birthday => (is=>'rw');
  has due => (is=>'rw');
  has profile => (is=>'ro');
  has credit_cards => (is=>'ro');
  has state_id =>(is=>'ro');
  has roles => (is=>'ro');

  validates ['first_name', 'last_name'] => (
    length => {
      maximum => 10,
      minimum => 3,
    }
  );

  validates profile => (object=>1); 
  validates credit_cards => (array=>[object=>1]); 
  validates roles => (array=>[object=>1]); 

  validates_with sub {
    my ($self, $opts) = @_;
    $self->errors->add(undef, 'Trouble 1', $opts);
    $self->errors->add(undef, 'Trouble 2', $opts);
    $self->errors->add('first_name', 'contains non alphabetic characters', $opts);
    $self->errors->add('status', 'bad value', $opts);
    $self->errors->add('type', 'bad value', $opts);
    $self->errors->add('birthday', 'bad value', $opts);
  };
}

ok my ($user, $admin, $guest) = map {
  Local::Role->new($_);
} (
  {id=>1, label=>'user'},
  {id=>2, label=>'admin'},
  {id=>3, label=>'guest'},
);

ok my $roles_collection = Valiant::HTML::Util::Collection->new($user, $admin, $guest);

ok my ($tx, $ny, $ca) = map {
  Local::State->new($_);
} (
  {id=>1, name=>'TX'},
  {id=>2, name=>'NY'},
  {id=>3, name=>'CA'},
);

ok my $states_collection = Valiant::HTML::Util::Collection->new($tx, $ny, $ca);

ok my $person = Local::Person->new(
  first_name=>'J', 
  last_name=>'Napiorkowski',
  birthday=>DateTime->new(year=>1969, month=>2, day=>13),
  due=>DateTime->new(year=>1969, month=>2, day=>13, hour=>10, minute=>45, second=>11, nanosecond=> 500000000, time_zone  => 'UTC'),
  profile=>Local::Profile->new(zip=>'78621', address=>'ab'),
  credit_cards=>[
    Local::CreditCard->new(number=>'234234223444', expiration=>DateTime->now->add(months=>11)),
    Local::CreditCard->new(number=>'342342342322', expiration=>DateTime->now->add(months=>11)),
    Local::CreditCard->new(number=>'111112222233', expiration=>DateTime->now->subtract(months=>11)),
  ],
  state_id => 1,
  roles=>[$user,$admin],
  type=>'admin');

ok $person->invalid; # runs validation and verify that the model has errors.

ok my $fb = Valiant::HTML::FormBuilder->new(
  model => $person,
  name => 'person');

is $fb->model_errors, '<ol><li>Trouble 1</li><li>Trouble 2</li></ol>';
is $fb->model_errors({class=>'foo'}), '<ol class="foo"><li>Trouble 1</li><li>Trouble 2</li></ol>';
is $fb->model_errors({max_errors=>1}), '<div>Trouble 1</div>';
is $fb->model_errors({max_errors=>1, class=>'foo'}), '<div class="foo">Trouble 1</div>';
is $fb->model_errors({show_message_on_field_errors=>1}), '<ol><li>Form has errors</li><li>Trouble 1</li><li>Trouble 2</li></ol>';
is $fb->model_errors({show_message_on_field_errors=>"Bad!"}), '<ol><li>Bad!</li><li>Trouble 1</li><li>Trouble 2</li></ol>';
is $fb->model_errors(sub {
  my (@errors) = @_;
  join " | ", @errors;
}), 'Trouble 1 | Trouble 2';

is $fb->label('first_name'), '<label for="person_first_name">First Name</label>';
is $fb->label('first_name', {class=>'foo'}), '<label class="foo" for="person_first_name">First Name</label>';
is $fb->label('first_name', 'Your First Name'), '<label for="person_first_name">Your First Name</label>';
is $fb->label('first_name', {class=>'foo'}, 'Your First Name'), '<label class="foo" for="person_first_name">Your First Name</label>';
is $fb->label('first_name', sub {
  my $translated_attribute = shift;
  return "$translated_attribute ",
    $fb->input('first_name');
}), '<label for="person_first_name">First Name <input id="person_first_name" name="person.first_name" type="text" value="J"/></label>';
is $fb->label('first_name', +{class=>'foo'}, sub {
  my $translated_attribute = shift;
  return "$translated_attribute ",
    $fb->input('first_name');
}), '<label class="foo" for="person_first_name">First Name <input id="person_first_name" name="person.first_name" type="text" value="J"/></label>';

is $fb->errors_for('first_name'), '<ol><li>First Name is too short (minimum is 3 characters)</li><li>First Name contains non alphabetic characters</li></ol>';
is $fb->errors_for('first_name', {class=>'foo'}), '<ol class="foo"><li>First Name is too short (minimum is 3 characters)</li><li>First Name contains non alphabetic characters</li></ol>';
is $fb->errors_for('first_name', {class=>'foo', max_errors=>1}), '<div class="foo">First Name is too short (minimum is 3 characters)</div>';
is $fb->errors_for('first_name', sub {
  my (@errors) = @_;
  join " | ", @errors;
}), 'First Name is too short (minimum is 3 characters) | First Name contains non alphabetic characters';
is $fb->errors_for('first_name', {max_errors=>1},sub {
  my (@errors) = @_;
  join " | ", @errors;
}), 'First Name is too short (minimum is 3 characters)';

is $fb->input('first_name'), '<input id="person_first_name" name="person.first_name" type="text" value="J"/>';
is $fb->input('first_name', {class=>'foo'}), '<input class="foo" id="person_first_name" name="person.first_name" type="text" value="J"/>';
is $fb->input('first_name', {errors_classes=>'error'}), '<input class="error" id="person_first_name" name="person.first_name" type="text" value="J"/>';
is $fb->input('first_name', {class=>'foo', errors_classes=>'error'}), '<input class="foo error" id="person_first_name" name="person.first_name" type="text" value="J"/>';

is $fb->password('first_name'), '<input id="person_first_name" name="person.first_name" type="password" value=""/>';
is $fb->password('first_name', {class=>'foo'}), '<input class="foo" id="person_first_name" name="person.first_name" type="password" value=""/>';
is $fb->password('first_name', {errors_classes=>'error'}), '<input class="error" id="person_first_name" name="person.first_name" type="password" value=""/>';
is $fb->password('first_name', {class=>'foo', errors_classes=>'error'}), '<input class="foo error" id="person_first_name" name="person.first_name" type="password" value=""/>';

is $fb->hidden('first_name'), '<input id="person_first_name" name="person.first_name" type="hidden" value="J"/>';
is $fb->hidden('first_name', {class=>'foo'}), '<input class="foo" id="person_first_name" name="person.first_name" type="hidden" value="J"/>';
is $fb->hidden('first_name', {errors_classes=>'error'}), '<input class="error" id="person_first_name" name="person.first_name" type="hidden" value="J"/>';
is $fb->hidden('first_name', {class=>'foo', errors_classes=>'error'}), '<input class="foo error" id="person_first_name" name="person.first_name" type="hidden" value="J"/>';

is $fb->text_area('first_name'), '<textarea id="person_first_name" name="person.first_name">J</textarea>';
is $fb->text_area('first_name', {class=>'foo'}), '<textarea class="foo" id="person_first_name" name="person.first_name">J</textarea>';
is $fb->text_area('first_name', {class=>'foo', errors_classes=>'error'}), '<textarea class="foo error" id="person_first_name" name="person.first_name">J</textarea>';

is $fb->checkbox('status'), '<input name="person.status" type="hidden" value="0"/><input id="person_status" name="person.status" type="checkbox" value="1"/>';
is $fb->checkbox('status', {class=>'foo'}), '<input name="person.status" type="hidden" value="0"/><input class="foo" id="person_status" name="person.status" type="checkbox" value="1"/>';
is $fb->checkbox('status', 'active', 'deactive'), '<input name="person.status" type="hidden" value="deactive"/><input id="person_status" name="person.status" type="checkbox" value="active"/>';
is $fb->checkbox('status', {include_hidden=>0}), '<input id="person_status" name="person.status" type="checkbox" value="1"/>';
$person->status(1);
is $fb->checkbox('status', {include_hidden=>0}), '<input checked id="person_status" name="person.status" type="checkbox" value="1"/>';
$person->status(0);
is $fb->checkbox('status', {include_hidden=>0, checked=>1}), '<input checked id="person_status" name="person.status" type="checkbox" value="1"/>';
is $fb->checkbox('status', {include_hidden=>0, errors_classes=>'err'}), '<input class="err" id="person_status" name="person.status" type="checkbox" value="1"/>';


is $fb->radio_button('type', 'admin'), '<input checked id="person_type_admin" name="person.type" type="radio" value="admin"/>';
is $fb->radio_button('type', 'user'), '<input id="person_type_user" name="person.type" type="radio" value="user"/>';
is $fb->radio_button('type', 'guest'), '<input id="person_type_guest" name="person.type" type="radio" value="guest"/>';

is $fb->radio_button('type', 'guest', {class=>'foo', errors_classes=>'err'}), '<input class="foo err" id="person_type_guest" name="person.type" type="radio" value="guest"/>';
is $fb->radio_button('type', 'guest', {checked=>1}), '<input checked id="person_type_guest" name="person.type" type="radio" value="guest"/>';

is $fb->date_field('birthday'), '<input id="person_birthday" name="person.birthday" type="date" value="1969-02-13"/>';
is $fb->date_field('birthday', {class=>'foo', errors_classes=>'err'}), '<input class="foo err" id="person_birthday" name="person.birthday" type="date" value="1969-02-13"/>';
is $fb->date_field('birthday', +{
  min => DateTime->new(year=>1900, month=>1, day=>1),
  max => DateTime->new(year=>2030, month=>1, day=>1),
}), '<input id="person_birthday" max="2030-01-01" min="1900-01-01" name="person.birthday" type="date" value="1969-02-13"/>';


is $fb->datetime_local_field('due'), '<input id="person_due" name="person.due" type="datetime-local" value="1969-02-13T10:45:11"/>';
is $fb->time_field('due'), '<input id="person_due" name="person.due" type="time" value="10:45:11.500"/>';
is $fb->time_field('due', +{include_seconds=>0}), '<input id="person_due" name="person.due" type="time" value="10:45"/>';

is $fb->submit, '<input id="commit" name="commit" type="submit" value="Submit Person"/>';
is $fb->submit('fff', {class=>'foo'}), '<input class="foo" id="commit" name="commit" type="submit" value="fff"/>';

is $fb->button('type'), '<button id="person_type" name="person.type" type="submit" value="admin">Button</button>';
is $fb->button('type', {class=>'foo'}), '<button class="foo" id="person_type" name="person.type" type="submit" value="admin">Button</button>';
is $fb->button('type', "Press Me"), '<button id="person_type" name="person.type" type="submit" value="admin">Press Me</button>';
is $fb->button('type', sub { "Press Me" }), '<button id="person_type" name="person.type" type="submit" value="admin">Press Me</button>';

is $fb->legend, '<legend>New Person</legend>';
is $fb->legend({class=>'foo'}), '<legend class="foo">New Person</legend>';
is $fb->legend("Person"), '<legend>Person</legend>';
is $fb->legend("Persons", {class=>'foo'}), '<legend class="foo">Persons</legend>';
is $fb->legend(sub { shift . " Info"}), '<legend>New Person Info</legend>';
is $fb->legend({class=>'foo'}, sub {"Person"}), '<legend class="foo">Person</legend>';

is $fb->fields_for('profile', sub {
  my $fb_profile = shift;
  return  $fb_profile->input('address'),
          $fb_profile->errors_for('address'),
          $fb_profile->input('zip');

}), '<input id="person_profile_address" name="person.profile.address" type="text" value="ab"/><div>Address is too short (minimum is 3 characters)</div><input id="person_profile_zip" name="person.profile.zip" type="text" value="78621"/>';

is $fb->fields_for('credit_cards', sub {
  my $fb_cc = shift;
  return  $fb_cc->input('number'),
          $fb_cc->date_field('expiration'),
          $fb_cc->errors_for('expiration');
}, sub {
  my $fb_finally = shift;
  return  $fb_finally->button('add', +{value=>1}, 'Add a New Credit Card');
}), '<input id="person_credit_cards_0_number" name="person.credit_cards[0].number" type="text" value="234234223444"/><input id="person_credit_cards_0_expiration" name="person.credit_cards[0].expiration" type="date" value="'.$person->credit_cards->[0]->expiration->ymd.'"/><input id="person_credit_cards_1_number" name="person.credit_cards[1].number" type="text" value="342342342322"/><input id="person_credit_cards_1_expiration" name="person.credit_cards[1].expiration" type="date" value="'.$person->credit_cards->[1]->expiration->ymd.'"/><input id="person_credit_cards_2_number" name="person.credit_cards[2].number" type="text" value="111112222233"/><input id="person_credit_cards_2_expiration" name="person.credit_cards[2].expiration" type="date" value="'.$person->credit_cards->[2]->expiration->ymd.'"/><div>Expiration chosen date can&#39;t be earlier than '.DateTime->now->ymd.'</div><button id="person_credit_cards_3_add" name="person.credit_cards[3].add" type="submit" value="1">Add a New Credit Card</button>';

is $fb->select('state_id', [1,2,3], +{class=>'foo'} ), '<select class="foo" id="person_state_id" name="person.state_id"><option selected value="1">1</option><option value="2">2</option><option value="3">3</option></select>';

is $fb->select('state_id', [1,2,3], +{selected=>[3], disabled=>[1],class=>'foo'} ), '<select class="foo" id="person_state_id" name="person.state_id"><option disabled value="1">1</option><option value="2">2</option><option selected value="3">3</option></select>';

is $fb->select('state_id', [map { [$_->name, $_->id] } $states_collection->all], +{include_blank=>1} ), '<select id="person_state_id" name="person.state_id"><option label=" " value=""></option><option selected value="1">TX</option><option value="2">NY</option><option value="3">CA</option></select>';

is $fb->select('state_id', sub {
  my ($model, $attribute, $value) = @_;
  return map {
    my $selected = $_->id eq $value ? 1:0;
    option_tag($_->name, +{class=>'foo', selected=>$selected, value=>$_->id}); 
  } $states_collection->all;
}), '<select id="person_state_id" name="person.state_id"><option class="foo" selected value="1">TX</option><option class="foo" value="2">NY</option><option class="foo" value="3">CA</option></select>';

is $fb->select({roles => 'id'}, [map { [$_->label, $_->id] } $roles_collection->all]), 
  '<input id="person_roles_id_hidden" name="person.roles[0]._nop" type="hidden" value="1"/>'.
  '<select id="person_roles_id" multiple name="person.roles[].id">'.
    '<option selected value="1">user</option>'.
    '<option selected value="2">admin</option>'.
    '<option value="3">guest</option>'.
  '</select>';



done_testing;

__END__


  ok my $body_parameters = [
    'person.roles[0]._nop' => '1',
    'person.roles[].id' => '',
    'person.roles[].id' => '1',
    'person.roles[].id' => '2',
  ];

  
<select id="person_roles_id" multiple name="person.roles[].id">
<option selected value="1">user</option>
<option selected value="2">admin</option>
<option value="3">guest</option>
</select>

    $fb->select('state', [1,2,3], +{class=>'foo'}),
    "\n..\n",

    $fb->select('state', +{class=>'foo'}, sub {
      my ($model, $attribute) = @_;
      return "...";
    }),


use Valiant::HTML::Form 'form_for';
use Valiant::HTML::SafeString 'raw';
use DateTime;

{
 package Local::Role;

  use Moo;
  use Valiant::Validations;

  sub namespace { 'Local' }
  
  has ['id', 'label'] => (is=>'ro', required=>1);

  package Local::PersonRole;

  use Moo;
  use Valiant::Validations;

  sub namespace { 'Local' }
  
  has ['role'] => (is=>'ro', required=>1);

  package Local::Test::Person;

  use Moo;
  use Valiant::Validations;

  has name => (is=>'ro');
  has date => (is=>'ro');
  has profile => (is=>'ro');
  has emails => (is=>'ro');
  has state => (is=>'ro');
  has state2 => (is=>'ro');
  has person_role => (is=>'ro');

  validates state => (presence=>1);

  validates name => (
    length => {
      maximum => 10,
      minimum => 5,
    },
    exclusion => 'John',
  );

  validates profile => (
    presence => 1,
    object => { nested => 1 },
  );

  validates emails => (
    presence => 1,
    array => { validations => [object=>1] },
  );

  sub namespace { 'Local::Test' }

  package Local::Test::Profile;

  use Moo;
  use Valiant::Validations;

  has address => (is=>'ro');
  has emails => (is=>'ro');

  validates address => (
    length => {
      maximum => 40,
      minimum => 3,
    },
  );

  validates emails => (
    presence => 1,
    array => { validations => [object=>1] },
  );

  sub namespace { 'Local::Test' }

  package Local::Test::Email;

  use Moo;
  use Valiant::Validations;

  has address => (is=>'ro');

  validates address => (
    length => {
      maximum => 10,
      minimum => 3,
    },
  );

  sub namespace { 'Local::Test' }

}

ok my $email1 = Local::Test::Email->new(address=>'jjn1@yahoo.com');
ok my $email2 = Local::Test::Email->new(address=>'jjn2@yahoo.com');
ok my $profile = Local::Test::Profile->new(address=>'123 Hello Street', emails=>[$email1, $email2]);

  my ($user, $admin, $guest) = map {
    Local::Role->new($_);
  } (
    {id=>1, label=>'user'},
    {id=>2, label=>'admin'},
    {id=>3, label=>'guest'},
  );

ok my $roles  = Valiant::HTML::Util::Collection->new($user, $admin, $guest);
ok my $person = Local::Test::Person->new(
  name=>'John',
  date=>DateTime->new(year=>2006,month=>1,day=>23, hour=>10,minute=>30,second=>15),
  profile=>$profile,
  emails => [$email1, $email2],
  state => 2,
  state2 => [1,3],
  person_role => Valiant::HTML::Util::Collection->new(
    $user, $guest,
  ),
);

ok $person->invalid;
ok my $collection = Valiant::HTML::Util::Collection->new([NY=>'1'], [CA=>'2'], [TX=>'3']);

warn form_for($person, +{data=>{main=>'person'}, class=>'main-form'}, sub {
  my $fb = shift;
  return
    $fb->model_errors(+{show_message_on_field_errors=>1}),
    $fb->label('name', +{data=>{a=>1}}),
    $fb->input('name', +{class=>'ddd'}),
    $fb->label('name', sub {
      my ($content) = @_;
      return 
        "..... $content .....",
        $fb->input('name', +{class=>'aaa'}),
        $fb->errors_for('name'); 
    }),
    $fb->errors_for('name', +{class=>'foo'}, sub {
        my (@errors) = @_;
        my @return = (
          (map { raw "Err:$_<br>"} @errors),
          $fb->password('name', +{class=>'password'}),
        );
        return @return;
    }),
    $fb->model_errors(+{show_message_on_field_errors=>1}, sub {
      my (@errors) = @_;
      return shift,
      $fb->hidden('name'),
    }),
    $fb->text_area('name', +{class=>'foo'}),
    $fb->checkbox('name'),
    $fb->radio_button('name', 'aa'),
    $fb->date_field('date'),
    $fb->datetime_local_field('date'),
    $fb->time_field('date'),
    $fb->time_field('date', +{include_seconds=>0}),
    "\n\n",
    $fb->fields_for('profile', sub {
      my $fb2 = shift;
      return $fb2->input('address'), "\n",
      $fb2->fields_for('emails', sub {
        my $fb3 = shift;
        return 
        $fb3->label('address'),
        $fb3->input('address'),
        $fb3->errors_for('address'), "\n";
      });
    }),
    "\n\n",
    $fb->fields_for('emails', sub {
      my $fb2 = shift;
      return 
      $fb2->label('address'),
      $fb2->input('address'),
      $fb2->errors_for('address'), "\n";
    }),
    "\n..\n",
    $fb->select('state', [1,2,3], +{class=>'foo'}),
    "\n..\n",

    $fb->select('state', +{class=>'foo'}, sub {
      my ($model, $attribute) = @_;
      return "...";
    }),
    "\n..\n",
    $fb->collection_select('state', $collection, value=>'label', +{class=>'foo'}),
    "\n..\n",
    $fb->collection_select('state', $collection),
    "\n..\n",
    $fb->collection_select('state2', $collection, value=>'label', +{class=>'foo'}),
    "\n..\n",
    $fb->collection_select({person_role => 'id'} , $roles, id=>'label'),
    "\n..\n",
    $fb->button('name', 'Press Me'),
    "\n..\n",
    $fb->submit,
    "\n..\n",
    $fb->collection_checkbox({person_role => 'id'} , $roles, id=>'label'),
    "\n..\n",
    $fb->collection_radio_buttons('state', $roles, id=>'label'),

    
});

{
  use HTML::Tags;

  {
    package XML::Tags::TIEHANDLE;

    sub one { warn 111 }
  }

  sub test123 {
    my $aaa = 'aaa';

    return HTML::Tags::to_html_string(
      <html>,
        <head>,
          <title>, "hello", </title>,
        </head>,
        <body class="$aaa">,
          form_for($person, +{data=>{main=>'person'}, class=>'main-form'}, sub {
            my $fb = shift;
            <div>, "tests", </div>,
            $fb->model_errors(+{show_message_on_field_errors=>1}),
            $fb->label('name', +{data=>{a=>1}}, sub {
              my ($content) = @_;
              <div>, $content, </div>,
            }),
            $fb->input('name', +{class=>'ddd'}),
          }),
        </body>,
      </html>
    );
  }
}

warn "\n\n-----\n\n";
warn test123;

done_testing;

__END__


{
  package Local::Test;

  use Moo;

  has a => (is=>'rw', lazy=>1, isa=>sub { warn 111; return 1}, default=> sub { 'default' });

  my $a = Local::Test->new;

  use Devel::Dwarn;
  Dwarn $a;
  
  warn $a->a;
  $a->a('b');
  warn $a->a;
}


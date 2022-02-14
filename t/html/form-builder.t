use Test::Most;
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


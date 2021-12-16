use Test::Most;
use Valiant::HTML::FormTags 'form_for', 'raw';

{
  package Local::Test::Person;

  use Moo;
  use Valiant::Validations;

  has name => (is=>'ro');

  validates name => (
    length => {
      maximum => 10,
      minimum => 5,
    },
    exclusion => 'John',
  );

  sub namespace { 'Local::Test' }
}

my $person = Local::Test::Person->new(name=>'John');
$person->validate;

warn form_for($person, sub {
  my $fb = shift;
  return $fb->label('name', +{data=>{a=>1}}),
    $fb->input('name', +{class=>'ddd'}),
    $fb->label('name', sub {
      my ($content, $options) = @_;
      return $fb->content("111 $content 222", "<a href=''>aaa</a>"),
        $fb->input('name', +{class=>'aaa'}),
        $fb->errors_for('name'); 
    }),
    "\n",
    $fb->errors_for('name', sub {
      my ($options, @errors) = @_;
      return join "\n", @errors;
    });
});

ok 1;

done_testing;

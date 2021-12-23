use Test::Most;
use Valiant::HTML::FormTags 'form_for';

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

ok my $person = Local::Test::Person->new(name=>'John');
ok $person->invalid;

warn form_for($person, sub {
  my $fb = shift;
  return
    $fb->model_errors(+{always_show_message=>1}),
    $fb->label('name', +{data=>{a=>1}}),
    $fb->input('name', +{class=>'ddd'}),
    $fb->password('name', +{class=>'password'}),
    $fb->label('name', sub {
      my ($content, $options) = @_;
      return $fb->content("111 $content 222", "<a href=''>aaa</a>"),
        $fb->input('name', +{class=>'aaa'}),
        $fb->errors_for('name'); 
    }),
    $fb->errors_for('name', sub {
      my ($options, @errors) = @_;
      return join "\n", @errors;
    });
});

done_testing;

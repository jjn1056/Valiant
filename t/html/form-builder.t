use Test::Most;
use Valiant::HTML::Form 'form_for';
use Valiant::HTML::SafeString 'raw';
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
      return raw shift,
      $fb->hidden('name'),
    }),
    $fb->text_area('name', +{class=>'foo'}),
    $fb->checkbox('name'),
    $fb->radio_button('name', 'aa');
});

done_testing;

__END__

<input class="is_invalid" id="local_test_person_name" name="person.name" type="hidden" value="0"/>
<input checked class="is_invalid" id="local_test_person_name" name="person.name" type="checkbox" value="1"/>

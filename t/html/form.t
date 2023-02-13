use Test::Most;
use Valiant::HTML::Form 'form_for';
use DateTime;
use Valiant::HTML::Util::Collection;
use Valiant::HTML::FormTags 'option_tag';

{
  package Local::Person;

  use Moo;
  use Valiant::Validations;
  use Valiant::Filters;

  has first_name => (is=>'ro');
  has last_name => (is=>'ro');
  
  validates ['first_name', 'last_name'] => (
    length => {
      maximum => 10,
      minimum => 3,
    }
  );
}

ok my $person = Local::Person->new(first_name => 'aa', last_name => 'napiorkowski');
ok !$person->valid;

{
  ok my $form = form_for($person, sub {
    my ($fb, $person) = @_;

    ok $fb->isa('Valiant::HTML::FormBuilder');
    ok $person->isa('Local::Person');

    return $fb->label('first_name'),
    $fb->input('first_name'),
    $fb->errors_for('first_name'),
    $fb->label('last_name'),
    $fb->input('last_name'),
    $fb->errors_for('last_name');
  });

  is $form, 
    '<form accept-charset="UTF-8" class="new_local_person" id="new_local_person" method="post">' .
      '<label for="local_person_first_name">First Name</label>' .
      '<input id="local_person_first_name" name="local_person.first_name" type="text" value="aa"/>' .
      '<div>First Name is too short (minimum is 3 characters)</div>' .
      '<label for="local_person_last_name">Last Name</label>' .
      '<input id="local_person_last_name" name="local_person.last_name" type="text" value="napiorkowski"/>' .
      '<div>Last Name is too long (maximum is 10 characters)</div>' .
    '</form>';
}

ok my $view = Valiant::HTML::Util::View->new(person=>$person);

{
  ok my $form = form_for('person', +{view=>$view}, sub {
    my ($fb, $person) = @_;

    ok $fb->isa('Valiant::HTML::FormBuilder');
    ok $person->isa('Local::Person');

    return $fb->label('first_name'),
    $fb->input('first_name'),
    $fb->errors_for('first_name'),
    $fb->label('last_name'),
    $fb->input('last_name'),
    $fb->errors_for('last_name');
  });

  is $form, 
    '<form accept-charset="UTF-8" class="new_local_person" id="new_local_person" method="post">' .
      '<label for="local_person_first_name">First Name</label>' .
      '<input id="local_person_first_name" name="local_person.first_name" type="text" value="aa"/>' .
      '<div>First Name is too short (minimum is 3 characters)</div>' .
      '<label for="local_person_last_name">Last Name</label>' .
      '<input id="local_person_last_name" name="local_person.last_name" type="text" value="napiorkowski"/>' .
      '<div>Last Name is too long (maximum is 10 characters)</div>' .
    '</form>';
}

done_testing;

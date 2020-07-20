package Valiant;

1;

=head1 TITLE

Valiant - Super heroic validations for Moo or Moose classes

=head1 SYNOPSIS

    package Local::Person;

    use Moo;
    use Valiant::Validations;

    has name => (is=>'ro');
    has age => (is=>'ro');

    validates name => (
      length => {
        maximum => 10,
        minimum => 3,
      }
    );

    validates age => (
      numericality => {
        is_integer => 1,
        less_than => 200,
      },
    );

    validates_with 'MySpecialValidator' => (arg1=>'foo', arg2=>'bar');

    my $person = Local::Person->new(
        name => 'Ja',
        age => 300,
      );

    $person->validate;
    $person->valid;     # FALSE
    $person->invalid;   # TRUE

    my %errors = $person->errors->to_hash(full_messages=>1);

    # \%errors = +{
    #   age => [
    #     "Age must be less than 200",
    #   ],
    #   name => [
    #     "Name is too short (minimum is 3 characters)',   
    #   ],
    # };

=head1 DESCRIPTION

Validations for your L<Moo> objects.  Allows you to defined for a given class what
a valid state for an instance of that class would be.  Used to defined constraints
related to business logic or for validating user input (for example via CGI forms).

The way this works is that it applies the L<Valiant::Validates> role and then
imports the C<validates>, C<valiates_with> and C<validates_each> class method from
that role.  This provides a local domain specific language for adding object level
validations as well as instance methods on blessed objects to run those validations,
inspect errors and perform some basic introspection / reflection on the validations.

Most of the guts of this is actually in L<Valiant::Validates> but since this class
will be your main point of entry to using L<Valiant> on Moo/se objects the main part
of the documentation will be here. 

Documentation here details using L<Valiant> with L<Moo> or L<Moose> based classes.
If you want to use L<Valiant> with L<DBIx::Class> you will also wish to review
L<DBIx::Class::Valiant> which details how L<Valiant> glues into L<DBIx::Class>.

Prior art for this would be the validations system for ActiveRecords in Ruby on Rails
and the Javascript library class-validator.js, both of which the author reviewed 
extensively when writing this code:

L<https://rubyonrails.org>, L<https://github.com/typestack/class-validator>

=head1 WHY OBJECT VALIDATIONS

Validating the state of things is one of the most common tasks we perform.  For example
a user might wish to change their profile information and you need to make sure that
the new settings conform to acceptable limits (such as the user first and last name
fits into the database and has acceptable characters, that a password is complex enough
and all that).  This logic can get tricky over time as a system grows in complexity and
edge cases need to be accounted for (for example for business reasons you might wish to
allow pre-existing users to conform to different password complexity constraints or require 
newer users to supply more profile details).

L<Valiant> offers a DSL (domain specific language) for adding validation meta data as
class data to your business objects.  This allows you to maintain separation of
concerns between the job of validation and the rest of your business logic but also keeps
the validation work close to the object that actually needs it, preventing action at a
distance confusion.  The actual validation code can be neatly encapsulated into standalone
validator classes (subclasses based on L<Valiant::Validator>) so they can be reused across
more than one business object. To bootstrap your validation work, L<Valiant> comes with a good
number of validators which cover many common cases, such as validating string lengths and
formats, date-time validation and numeric validations.  Lastly, the validation meta data
which is added via the DSL can aggregate across consumed roles and inherited classes.  So
you can create shared roles and base classes which defined validations that are used in many
places.

Once you have decorated your business logic classes with L<Valiant> validations, you can 
run those validations on blessed instances of those classes and inspect errors.  There is
also some introspection capability making it possible to do things like generate display UI
from your errors.

=head1 EXAMPLES

The following are some example cases of how one can use L<Valiant> to perform object validation

=head2 The simplest possible case

At its most simple, a validation can be just a reference to a subroutine which adds validation
error messages based on conditions you code:

    package Local::Simple

    use Valiant::Validations;
    use Moo;

    has name => (is => 'ro');
    has age => (is => 'ro);

    validates_with sub {
      my ($self, $opts) = @_;
      $self->errors->add(name => "Name is too long") if length($self->name) > 20;
      $self->errors->add(age => "Age can't be negative") if  $self->age < 1;
    };

    my $simple = Local::Simple->new(
      name => 'A waaay too loooong name', # more than 20 characters
      age => -10, # less than 1
    );

    $simple->validate;
    $simple->valid;     # FALSE
    $simple->invalid;   # TRUE

    my %errors = $simple->errors->to_hash(full_messages=>1);

    #\%errors = {
    #  age => [
    #    "Age can't be negative",
    #  ],
    #  name => [
    #    "Name is too long",
    #  ],
    #}

One thing you should note is that if you are using validations you probably won't be adding
type constraints on your L<Moo> or L<Moose> attributes.  That is because the validations run
on an instance of the class.  The only time you'd use a constraint on your attribute declaration
is if you really wanted to throw a hard exception (for example the user supplies a value that
is so out of bounds that the object can't be created).

The subroutine reference that the C<validates_with> keyword accepts will receive the blessed
instance as the first argument and a hash of options as the second.  Options are added as
additional arguments after the subroutine reference.  This makes it easier to create parameterized
validation methods:

    package Local::Simple2;

    use Valiant::Validations;
    use Moo;

    has name => (is => 'ro');
    has age => (is => 'ro');

    validates_with \&check_length, length_max => 20;
    validates_with \&check_age_lower_limit, min => 5;

    sub check_length {
      my ($self, $opts) = @_;
      $self->errors->add(name => "is too long") if length($self->name) > $opts->{length_max};
    }

    sub check_age_lower_limit {
      my ($self, $opts) = @_;
      $self->errors->add(age => "can't be lower than $opts->{min}") if $self->age < $opts->{min};
    }

    my $simple2 = Local::Simple2->new(
      name => 'A waaay too loooong name',
      age => -10,
    );

    $simple2->validate;
    $simple2->valid;     # FALSE
    $simple2->invalid;   # TRUE

    my %errors = $simple2->errors->to_hash(full_messages=>1);

    #\%errors = {
    #  age => [
    #    "Age can't be lower than 5",
    #  ],
    #  name => [
    #    "Name is too long",
    #  ],
    #}

The validation methods have access to the fully blessed instance you can create complex
validation rules based on your business requirements.

Since many of your validations will be directly on attributes of you object, you can use the
C<validates> keyword which offers some shortcuts and better code reusabilitu for attributes.
We can rewrite the last class as follows:

    package Local::Simple3;

    use Valiant::Validations;
    use Moo;

    has name => (is => 'ro');
    has age => (is => 'ro');

    validates name => ( \&check_length => { length_max => 20 } );
    validates age => ( \&check_age_lower_limit => { min => 5 } );

    sub check_length {
      my ($self, $attribute, $value, $opts) = @_;
      $self->errors->add($attribute => "is too long", $opts) if length($value) > $opts->{length_max};
    }

    sub check_age_lower_limit {
      my ($self, $opts) = @_;
      $self->errors->add($attribute => "can't be lower than $opts->{min}", $opts) if $value < $opts->{min};
    }

    my $simple3 = Local::Simple2->new(
      name => 'A waaay too loooong name',
      age => -10,
    );

    $simple3->validate;

    my %errors = $simple3->errors->to_hash(full_messages=>1);

    #\%errors = {
    #  age => [
    #    "Age can't be lower than 5",
    #  ],
    #  name => [
    #    "Name is too long",
    #  ],
    #}

Using the C<validates> keyword allows you to name the attribute for which the validations are intended.
When you do this the signature of the arguments for the subroutine reference changes to included both
the attribute name (as a string) and the current attribute value.  This is useful since you can now
use the validation method across different attributes, avoiding hardcoding its name into your validation rule.
One difference from C<validates_with> you will note is that if you want to pass arguments to the options hashref
you need to use a hashref and not a hash.  This is due to the fact that C<validates> can take a list of
validators, each with its own arguments. For example you could have the following:

    validates name => (
      \&check_length => { length_max => 20 },
      \&looks_like_a_name,
      \&is_unique_name_in_database,
    );

Also, similiar to the C<has> keyword that L<Moo> imports, you can use an arrayref of attribute name for grouping
those with the same validation rules:

    validates ['first_name', 'last_name'] => ( \&check_length => { length_max => 20 } );

At this point you can see how to write fairly complex and parameterized validations on your attributes
directly or on the object as a whole (using C<validates> for attributes and C<validates_with> for validations
that are not directly tied to an attribute but instead validate the object as a whole).  However it is
often ideal to isolate your validation logic into a stand alone class to promote code reuse as well as
better separate your valiation logic from your classes.  

=head2 Using a validator class

Although you could use subroutine references for all your validation if you did so you'd likely end
up with a lot of repeated code across your classes.  This is because a lot of validations are standard
(such as string length and allowed characters, numeric ranges and so on).  As a result you will likely
build at least some custom validators and make use of the prepacked ones that ship with L<Valiant>.
Lets return to one of the earlier examples that used C<valiates_with> but instead of using a subroutine
reference we will rewrite it as a custom validator:

    package Local::Person::Validator::Custom;

    use Moo;
    with 'Valiant::Validator';

    has 'max_name_length' => (is=>'ro', required=>1);
    has 'min_age' => (is=>'ro', required=>1);

    sub validate {
      my ($self, $object, $opts) = @_;
      $object->errors->add(name => "is too long") if length($object->name) > $self->max_name_length;
      $object->errors->add(age => "can't be lower than @{[ $self->min_age ]}") if $object->age < $self->min_age;
    }

And use it in a class:

    package Local::Person;

    use Valiant::Validations;
    use Moo;

    has name => (is => 'ro');
    has age => (is => 'ro');

    validates_with Custom => (
      max_name_length => 20, 
      min_age => 5,
    );

    my $person = Local::Person->new(
      name => 'A waaay too loooong name',
      age => -10,
    );

    $person->validate;
    $person->invalid; # TRUE

    my %errors = $person->errors->to_hash(full_messages=>1) };

    #\%errors =  +{
    #  age => [
    #    "Age can't be lower than 5",
    #  ],
    #  name => [
    #    "Name is too long",
    #  ],
    #}; 

A custom validator is just a class that does the C<validate> method (although I recommend that you
consume the L<Valiant::Validator> role as well; this might be required at some point).  When this validator
is added to a class, it is instantiated once with any provided arguments (which are passed to C<new> as init_args).
Each time your call validate, it runs the C<validate> method with the following signature:

    sub validate {
      my ($self, $object, $opts) = @_;
      $object->errors->add(...) if ...
    }

Where C<$self> is the validator object, C<$object> is the current instance of the class you are
validating and C<$opts> is the options hashref.

Within this method you can do any special or complex validation and add error messages to the C<$object>
based on its current state.

=head2 Custom Validator Namespace Resolution

When you use a custom validator class namepart (either via C<validates> or
C<validates_with>) we search thru a number of namespaces to find a match.  This is done
to allow you to create increasingly custom valiators for your classes.  Basically we start with the
package name of the class which is adding the validator, add "::Validator::${namepart}" and then look
down the namespace tree for a loadable file.  If we don't find a match in your project package
namespace we then also look in the two globally shared namespaces C<Valiant::ValidatorX> and
C<Valiant::Validator>.  If we still don't find a match we then throw an exception.  For example
if your package is named C<Local::Person> as in the class above and you specify the C<Custom> validator
we will search for it in all the namespaces below, in order written:

    Local::Person::Validator::Custom
    Local::Validator::Custom
    Validator::Custom
    Valiant::ValidatorX::Custom
    Valiant::Validator::Custom

B<NOTE:> The namespace C<Valiant::Validator> is reserved for validators that ship with L<Valiant>.  The
C<Valiant::ValidatorX> namespace is reserved for additional validators on CPAN that are packaged separately
from L<Valiant>.  If you wish to share a custom validator that you wrote the proper namespace to use on
CPAN is C<Valiant::ValidatorX>.

You can also prepend your validator name with '+' which will cause L<Valiant> to ignore the namespace 
resolution and try to load the class directly.  For example:

    validates_with '+App::MyValidator';

Will try to load the class C<App::MyValidator> and use it as a validator directly (or throw an exception if
it fails to load).

=head2 Validator classes and attributes

Since many of your validations will be on your class's attributes, L<Valiant> makes it easy to use custom
and prepackaged validator classes directly on attributes.  All validator classes which operate on attributes
must consume the role L<Valiant::Validator::Each>.  Here's an example of a class which is using several of
the prepackaged attribute validator classes that comes with L<Valiant>.

    package Local::Task;

    use Valiant::Validations;
    use Moo;

    has priority => (is => 'ro');
    has description => (is => 'ro');
    has due_date => (is => 'ro');

    validates priority => (
      presence => 1,
      numericality => { only_integer => 1, between => [1,10] },
    );

    validates description => (
      presence => 1,
      length => [10,60],
    );

    validates due_date => (
      presence => 1,
      date => 'is_future',
    );

In this case our class defines three attributes, 'priority' (which defined how important a task
is), 'description' (which is a human read description of the task that needs to happen) and
a 'due_date' (which is when the task should be completed).  We then have validations which
place some constraints on the allowed values for these attributes.  Our validations state that:

    'priority' must be defined, must be an integer and the number must be from 1 thru 10.
    'description' must be defined and a string that is longer than 10 characters but less than 60.
    'due_date' must be in a date format (YYYY-MM-DD or eg. '2000-01-01') and also must be a future date.

This class uses the following validators: L<Valiant::Validator::Presence>, to verify that the attribute
has a meaningful defined value; L<Valiant::Validator::Numericality>, to verify the value is an integer and is
between 1 and 10; L<Valiant::Validator::Length>, to check the length of a string and 
L<Valiant::Validator::Date> to verify that the value looks like a date and is a date in the future.

Canonically a validator class accepts a hashref of options, but many of the packaged validators also
accept shortcut forms for the most common use cases.  For example since its common to require a date be
sometime in the future you can write "date => 'is_future'".Documentation for these shortcut forms are detailed
in each validator class.

=head2 Creating a custom attribute validator class

Creating your own custom attribute validator classes is just as easy as it was for creating a general
validator class.  You need to write a L<Moo> class that consumes the L<Valiant::Validator::Each> role
and provides a C<validates_each> method with the following signature:

    sub validates_each {
      my ($self, $object, $attribute, $value, $opts) = @_; 
    }

Where C<$self> is the validator class instance (this is created once when the validator is added to the class),
C<$object> is the instance of the class you are validating, C<$attribute> is the string name of the attribute
this validation is running on, C<$value> is the current attribute's value and C<$opts> is a hashref of options
passed to the class.  For example, here is simple Boolean truth validator:

    package Local::Application::Validator::True;

    use Moo;

    with 'Valiant::Validator::Each';

    sub validate_each {
      my ($self, $object, $attribute, $value, $opts) = @_;
      $object->errors->add($attribute, 'is not a truth value', $opts) unless $value;
    }

Two things to note: There is no meaning assigned to the return value of C<validate_each> (or of C<validates>).
Also you should remember to pass C<$opts> as the third argument to the C<add> method.  Even if you are not
using the options hashref in your custom validator, it might contain values that influence other aspects
of the framework, such as how the error message is formatted.

When resolving a validator namepart, the same rules described above for general validator classes apply.

=head1 PREPACKAGED VALIDATOR CLASSES

The following attribute validator classes are shipped with L<Valiant>.  Please see the package POD for
usage details (this is only a sparse summary)

=head2 Absence

Checks that a value is absent (undefinef or empty).

See L<Valiant::Validator::Absence> for details.

=head2 Array

Validations on an array value.  Has options for nested errors when the array contains objects that
themselves are validatible.

See L<Valiant::Validator::Array> for details.

=head2 Boolean

Returns errors messages based on the boolean state of an attribute.

See L<Valiant::Validator::Boolean> for details.

=head2 Check

Use your existing L<Type::Tiny> constraints with L<Valiant>

See L<Valiant::Validator::Check> for details.

=head2 Confirmation

Add a confirmation error check.  Used for when you want to verify that a given field is correct
(such as when a user submits a new password or an email address).

See L<Valiant::Validator::Confirmation> for details.

=head2 Date

Value must conform to standard date format (default is YYYY-MM-DD or eg 2000-01-01) and be a valid date.

See L<Valiant::Validator::Date> for details.

=head2 Exclusion

Value cannot match a fixed list.

See L<Valiant::Validator::Exclusion> for details.

=head2 Format

Value must be a string tht matched a given format or regular expression.

See L<Valiant::Validator::Format> for details.

=head2 Inclusion

Value must be one of a fixed list

See L<Valiant::Validator::Inclusion> for details.

=head2 Length

Value must be a string with given minimum and maximum lengths.

See L<Valiant::Validator::Length> for details.

=head2 Numericality

Validate various types of numbers.

See L<Valiant::Validator::Numericality> for details.

=head2 Object

Value is an object.  Allows one to have nested validations when the object itself can be validated.

See L<Valiant::Validator::Object> for details.

=head2 OnlyOf

Validates that only one or more of a group of attributes is defined.  

See L<Valiant::Validator::OnlyOf> for details.

=head2 Presence

That the value is defined and not empty

See L<Valiant::Validator::Absence> for details.

=head2 Unique

That the value is unique based on some custom logic that your class must provide.

See L<Valiant::Validator::Unique> for details.

=head2 With

Use a subroutine reference or the name of a method on your class to provide validation.

See L<Valiant::Validator::With> for details.

=head2 Special Validators

The following validators are not considered for end users but have documentation you might
find useful in furthering your knowledge of L<Valiant>:  L<Valiant::Validator::Collection>,
L<Valiant::Validator::Each>.
   
=head1 TYPE CONSTRAINT SUPPORT

If you are comfortable using common type contraint libaries such as L<Type::Tiny> you can
use those directly as validation rules much in the same way you can use subroutine references.

    package Local::Test::Check;

    use Moo;
    use Valiant::Validations;
    use Types::Standard 'Int';

    has drinking_age => (is=>'ro');

    validates drinking_age => (
      Int->where('$_ >= 21'), +{
        message => 'is too young to drink!',
      },
    );

Please note this is just wrapping L<Valiant::Validator::Check> so if you need more control
you might prefer to use the validator class.

=head1 INHERITANCE AND ROLES

You can aggregate validation rules via inheritance and roles.  This makes it so that if you
have a number of classes with similar validation rules you can avoid repeating yourself.
Example:

    package Person;

    use Moo;
    use Valiant::Validations;

    has 'name' => (is=>'ro',);
    has 'age' => (is=>'ro');

    validates name => (
      presence => 1,
      length => [3,20],
    );

    validates age => (
      numericality => {
        only_integer => 1,
        greater_than => 0,
        less_than => 150,
      },
    );

    package IsRetirementAge;

    use Moo::Role;
    use Valiant::Validations;

    requires 'age';

    validates age => (
      numericality => {
        greater_than => 64,
      },
    );

    package Retiree;

    use Moo;
    use Valiant::Validations;

    with 'IsRetirementAge';

    1;

    my $retiree = Retiree->new(name=>'Molly Millions', age=>24);

    $retiree->invalid; # true

    my %errors = $object->errors->to_hash(full_messages=>1);
    # \%errors = +{
    #   age => ["Age must be greater than 64" ]
    # }

=head1 GLOBAL VALIDATOR OPTIONS

All validators can accept the following options.  Options can be added to each
validator separately (if you have several) or can be added globally to the end
of the validator rules.  Global rules run first, followed by those applied to
each validator.

=head2 allow_undef

If the attribute value is undef, skip validation and allow it.

    package Person;

    use Moo;
    use Valiant::Validations;

    has 'name' => (is=>'ro',);
    has 'age' => (is=>'ro');

    validates name => (
      format => 'alphabetic',
      length => [3,20],
      allow_undef => 1, # Skip BOTH 'format' and 'length' validators if 'name' is undefined.
    );

    validates age => (
      numericality => {
        only_integer => 1,
        greater_than => 0,
        less_than => 150,
        allow_undef => 1,  # Skip only the 'numericality' validator if 'age' is undefined
      },
    );
 
=head2 allow_blank

If the attribute is blank (that is its one of undef, '', or a scalar composing only
whitespace) skip validation and allow it.  This is similar to the C<allow_undef> option
except it allows a broader definition of 'blank'.  Useful for form validations.

=head2 if / unless

Accepts a coderef or the name of a method which executes and is expected to
return true or false.  If false we skip the validation (or true for C<unless>).
Recieves the object, the attribute name, value to be checked and the options hashref
as arguments.

You can set more than one value to these with an arrayref:

    if => ['is_admin', sub { ... }, 'active_account'],

Example:

    package Person;

    use Moo;
    use Valiant::Validations;

    has 'name' => (is=>'ro',);
    has 'password' => (is=>'ro'); 

    validates name => (
      format => 'alphabetic',
      length => [3,20],
    );

    validates password => (
      length => [12,32],
      with => \&is_a_secure_looking_password,
      unless => sub {
        my ($self, $attr, $value, $opts) = @_;
        $self->name eq 'John Napiorkowski';  # John can make an insecure password if he wants!
      },
    );

=head2 message

Provide a global error message override for the constraint.  Will accept a string,
a translation tag, a reference to a string or a reference to a function.  Using
this will override the custom error message provided by the validator.

    package Person;

    use Moo;
    use Valiant::Validations;

    has 'name' => (is=>'ro',);
    has 'age' => (is=>'ro');

    validates name => (
      format => 'alphabetic',
      length => [3,20],
      message => 'Unacceptable Name', # Overrides both the 'format' and 'length' messages.
    );

    validates age => (
      presence => 1,
      numericality => {
        only_integer => 1,
        greater_than => 0,
        less_than => 150,
        message => 'Age given is not valid',  # overrides just the 'numericality' messages
                                              # and not the 'presence' message.
      },
    );

Please not that many validators also provide error type specific messages for custom
errors (as well as the ability to setup your own errors in a localization file.)  Using 
this attribute is the easiest but probably not always your best option.

Messages can be:

=over4

=item A string

If a string this is the error message recorded.

    validates name => (
      format => 'alphabetic',
      length => [3,20],
      message => 'Unacceptable Name',
    );

=item A translation tag

    use Valiant::I18N;

    validates name => (
      format => 'alphabetic',
      length => [3,20],
      message => _t('bad_name'),
    );

This will look up a translated version of the tag.  See L<Valiant::I18N> for more details.

=item A scalar reference

    validates name => (
      format => 'alphabetic',
      length => [3,20],
      message => \'Unacceptable {{attribute}}',
    );

Similar to string but we will expand any placeholder variables which are indicated by the
'{{' and '}}' tokens (which are removed from the final string).  You can use any placeholder
that is a key in the options hash (and you can pass additional values when you add an error).
By default the following placeholder expansions are available attribute (the attribute name),
value (the current attribute value), model (the human name of the model containing the
attribute and object (the actual object instance that has the error).

=item A subroutine reference

    validates name => (
      format => 'alphabetic',
      length => [3,20],
      message => sub {
        my ($self, $attr, $value, $opts) = @_;
        return "Unacceptable $attr!";
      }
    );

Similar to the scalar reference option just more flexible since you can write custom code
to build the error message.  For example you could return different error messages based on
the identity of a person.

=back

=head2 strict

When true instead of adding a message to the errors list, will throw exception with the
error instead.  If the true value is the name of a class that provides a C<throw>
message, will use that instead.

=head2 on

A scalar or list of contexts that can be used to control the situation ('context')
under which the validation is executed. If you specify an C<on> context that 
validation will only run if you pass that context via C<validate>.  However if you
don't set a context for the validate (in other words you don't set an C<on> value)
then that validation ALWAYS runs (whether or not you set a context via C<validates>.
Basically not setting a context means validation runs in all contexts and none.
Examples:

  package Local::Test::Person;

  use Moo;
  use Valiant::Validations;
  use Valiant::I18N;

  has age => (is=>'ro');

  validates age => (
    numericality => {
      is_integer => 1,
      less_than => 200,
    },
    numericality => {
      is_integer => 1,
      greater_than_or_equal_to => 18,
      on => 'voter',
    },
    numericality => {
      is_integer => 1,
      greater_than_or_equal_to => 65,
      on => 'retiree',
    },
    numericality => {
      is_integer => 1,
      greater_than_or_equal_to => 100,
      on => 'centarion',
    },
  );

  my $person = Local::Test::Person->new(age=>50);

  $person->validate();
  $person->valid; # True.

  $person->validate(context=>'retiree');
  $person->valid; # False; "Age must be greater than or equal to 65"

  $person->validate(context=>'voter');
  $person->valid; # True.

  $person->validate(context=>'centarion');
  $person->valid; # False; "Age must be greater than or equal to 100"

=head1 ERROR MESSAGES
=head1 WORKING WITH ERRORS
=head1 INTERNATONALIZATION
=head1 NESTED OBJECTS AND ARRAYS

=head1 SEE ALSO
 
L<Valiant>, L<Valiant::Validations>, L<Valiant::Validates>

=head1 COPYRIGHT & LICENSE
 
Copyright 2020, John Napiorkowski L<email:jjnapiork@cpan.org>
 
This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut


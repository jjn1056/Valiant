package Valiant::Validations;

use Sub::Exporter 'build_exporter';
use Class::Method::Modifiers qw(install_modifier);
use Valiant::Util 'debug';

require Role::Tiny;

sub default_roles { 'Valiant::Validates' }
sub default_exports { qw(validates validates_with validates_each) }

sub import {
  my $class = shift;
  my $target = caller;

  foreach my $default_role ($class->default_roles) {
    next if Role::Tiny::does_role($target, $default_role);
    debug 1, "Applying role '$default_role' to '$target'";
    Role::Tiny->apply_roles_to_package($target, $default_role);
  }

  my %cb = map {
    $_ => $target->can($_);
  } $class->default_exports;
  
  my $exporter = build_exporter({
    into_level => 1,
    exports => [
      map {
        my $key = $_; 
        $key => sub {
          sub { return $cb{$key}->($target, @_) };
        }
      } keys %cb,
    ],
  });

  $class->$exporter($class->default_exports);

  install_modifier $target, 'around', 'has', sub {
    my $orig = shift;
    my ($attr, %opts) = @_;

    my $method = \&{"${target}::validates"};
 
    if(my $validates = delete $opts{validates}) {
      debug 1, "Found validation in attribute '$attr'";
      $method->($attr, @$validates);
    }
      
    return $orig->($attr, %opts);
  } if $target->can('has');
} 

1;

=head1 TITLE

Valiant::Validations - Addos a validation DSL and API to your Moo/se classes

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

Validators on specific attributes can be added to the C<has> clause if you prefer:

    package Local::Person;

    use Moo;
    use Valiant::Validations;

    has name => (
      is => 'ro',
      validates => [
        length => {
          maximum => 10,
          minimum => 3,
        },
      ],
    );

    has age => (
      is => 'ro',
      validates => [
        numericality => {
          is_integer => 1,
          less_than => 200,
        },
      ],
    );

Using validations on objects:

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

See below for details of the full API as well as L<Valiant::Validates> which is the role
which defines the API.

=head1 DESCRIPTION

Validations for your L<Moo> objects.  Allows you to defined for a given class what
a valid state for an instance of that class would be.  Used to defined constraints
related to business logic or for validating user input (for example via CGI forms).

The way this works is that it applies the L<Valiant::Validates> role and then
import the C<validates>, C<valiates_with> and C<validates_each> class method from
that role.  This provides a local domain specific language for adding object level
validations as well as instance methods on blessed objects to run those validations,
inspect errors and perform some basic introspection / reflection on the validations.

Most of the guts of this is actually in L<Valiant::Validates> but since this class
will be your main point of entry to using L<Valiant> on Moo/se objects the main part
of the documentation will be here. 

Documentation here details using L<Valiant> with L<Moo> or L<Moose> based classes.
If you want to use L<Valiant> with L<DBIx::Class> you will also wish to review
L<DBIx::Class::Valiant> which details how L<Valiant> glues into L<DBIx::Class>.

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
also some instrospection capability making it possible to do things like generate display UI
from your errors.

=head1 EXAMPLE

A simple example case.  Your application is a TODO list and you have a business object
called 'Task' which encapsulates all the rules around creating and updating tasks in that
list.  One set of business rules defines the attributes of that class and another the
constraints on field members of that class.

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
    'due_date' must be in a date format (YYYY-MM-DD or 2000-01-01) and also must be a future date.


=head1 IMPORTS

The following subroutines are imported from L<Valiant::Validates>

    validates_with sub {
      my ($self, $attr_name, $value, $opts) = @_;
    };

    valiates_with 'SpecialValidator', arg1=>'foo', arg2=>'bar';

    validates_each 'name', 'age', sub {
      my ($self, $attr_name, $value, $opts) = @_;
    }

=head1 ATTRIBUTES

The following attributes are provided via L<Valiant::Validates>

=head1 METHODS

The following methods are provided via L<Valiant::Validates>

=head1 SEE ALSO
 
L<Valiant>, L<Valiant::Validates>

=head1 AUTHOR
 
See L<Valiant>

=head1 COPYRIGHT & LICENSE
 
See L<Valiant>

=cut

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

Valiant::Validations - Add a validations DSL to your Moo/se classes

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
which defines the API (additional API docs there).

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

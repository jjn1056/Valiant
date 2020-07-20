package Valiant::Validations;

use Sub::Exporter 'build_exporter';
use Class::Method::Modifiers qw(install_modifier);
use Valiant::Util 'debug';

require Role::Tiny;

our @DEFAULT_ROLES = (qw(Valiant::Validates));
our @DEFAULT_EXPORTS = (qw(validates validates_with validates_each));

sub default_roles { @DEFAULT_ROLES }
sub default_exports { @DEFAULT_EXPORTS }

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

See L<Valiant> for overall overview and L<Valiant::Validates> for additional API
level documentation.

=head1 DESCRIPTION

Using this package will apply the L<Valiant::Validates> role to your current class
as well as import several class methods from that role.  It also wraps the C<has>
imported method so that you can add attribute validations as arguments to C<has> if
you find that approach to be neater than calling C<validates>.

You can override several class methods of this package if you need to create your
own custom subclass.

=head1 IMPORTS

The following subroutines are imported from L<Valiant::Validates>

=head2 validates_with

Accepts the name of a custom validator or a reference to a function, followed by a list
of arguments.  

    validates_with sub {
      my ($self, $opts) = @_;
    };

    valiates_with 'SpecialValidator', arg1=>'foo', arg2=>'bar';

See C<validates_with> in either L<Valiant> or L<Valiant::Validates> for more.

=head2 validates

Create validations on an objects attributes.  Accepts the name of an attributes (or an
arrayref of names) followed by a list of validators and global options.  Validators can
be a subroutine reference, a type constraint or the name of a Validator class.

See C<validates> in either L<Valiant> or L<Valiant::Validates> for more.

=head1 METHODS

The following class methods are available for subclasses

=head2 default_role

Roles that are applied when using this class.  Default is L<Valiant::Validates>.  If
you are subclassing and wish to apply more roles, or if you've made your own version
of L<Valiant::Validates> you can override this method.

=head2 default_exports

Methods that are automatically exported into the calling package.

=head1 SEE ALSO
 
L<Valiant>, L<Valiant::Validates>

=head1 AUTHOR
 
See L<Valiant>

=head1 COPYRIGHT & LICENSE
 
See L<Valiant>

=cut

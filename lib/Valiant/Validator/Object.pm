package Valiant::Validator::Object;

use Moo;
use Valiant::I18N;
use Module::Runtime 'use_module';

with 'Valiant::Validator::Each';

has validations => (is=>'ro', required=>1);
has validator => (is=>'ro', required=>0);
has for => (is=>'ro', required=>0, predicate=>'has_for');

around BUILDARGS => sub {
  my ( $orig, $class, @args ) = @_;
  my $args = $class->$orig(@args);
  my $for = delete $args->{for};

  if($args->{namespace}) {
    $args->{for} = $args->{namespace};
  }

  if( ((ref($args->{validations})||'') eq 'ARRAY') && !exists $args->{validator} ) {
    my $validator = use_module($args->{validator_class}||'Valiant::Class')
      ->new(
        %{ $args->{validator_class_args}||+{} },
        for => $for, 
        validations => $args->{validations}
      );
    $args->{validator} = $validator;
  }

  return $args;
};

sub normalize_shortcut {
  my ($class, $arg) = @_;
  if(($arg eq '1') || ($arg eq 'nested')) {
    return { validations => 1 };
  } elsif( (ref(\$arg)||'') eq 'SCALAR') {
    return { for => $arg, validations => [] };
  } elsif( (ref($arg)||'') eq 'ARRAY') {
    return { validations => $arg };
  }

}

sub validate_each {
  my ($self, $record, $attribute, $value, $options) = @_;
  my %opts = (%{$self->options}, %{$options||{}});
  my $validates = $self->_cb_value($record, $self->validations);

  if($validates) {
    if(my $validator = $self->validator) {
      my $result = $validator->validate($value, %opts);
      if($result->invalid) {
        $record->errors->add($attribute, $result->errors, \%opts);
      }
    } else {
      $value->validate(%opts);
      if($value->errors->size) {
        $record->errors->add($attribute, $value->errors, \%opts);
      }
    }
  }
}

1;

=head1 TITLE

Valiant::Validator::Object - Verify a related object

=head1 SYNOPSIS

    package Local::Test::Address {

      use Moo;
      use Valiant::Validations;

      has street => (is=>'ro');
      has city => (is=>'ro');
      has country => (is=>'ro');

      validates ['street', 'city'],
        presence => 1,
        length => [3, 40];

      validates 'country',
        presence => 1,
        inclusion => [qw/usa uk canada japan/];
    }

    package Local::Test::Person {

      use Moo;
      use Valiant::Validations;

      has name => (is=>'ro');
      has address => (is=>'ro');

      validates name => (
        length => [2,30],
        format => qr/[A-Za-z]+/, #yes no unicode names for this test...
      );

      validates address => (
        presence => 1,
        object => {
          validations => 1,
        }
      )
    }

    my $address = Local::Test::Address->new(
      city => 'NY',
      country => 'Russia'
    );

    my $person = Local::Test::Person->new(
      name => '12234',
      address => $address,
    );

    $person->validate;

    warn $person->errors->_dump;

    $VAR1 = {
      'name' => [
        'Name does not match the required pattern'
      ],
      'address' => [
          {
             'country' => [
                            'Country is not in the list'
                          ],
             'street' => [
                           'Street can\'t be blank',
                           'Street is too short (minimum is 3 characters)'
                         ],
             'city' => [
                         'City is too short (minimum is 3 characters)'
                       ]
          },
      ],
    };

=head1 DESCRIPTION

Runs validations on an object which is assigned as an attribute and
aggregates those errors (if any) onto the parent object.

Useful when you need to validate an object graph or nested forms.

If your nested object has a nested object it will follow all the way
down the rabbit hole  Just don't make self referential nested objects;
that's not tested and likely to end poorly.  Patches welcomed.

=head1 INLINED VALIDATIONS

Sometimes you may wish to apply validations to an associated object that
doesn't have any itself (perhaps its a third party class that you can't
control for example).  In this case you can add inlined validation rules.

  package Local::Test::Person;

  use Moo;
  use Valiant::Validations;

  has name => (is=>'ro');
  has car => (is=>'ro');

  validates name => (
    length => [2,30],
    format => qr/[A-Za-z]+/, #yes no unicode names for this test...
  );

  validates car => (
    object => {
      for => 'Local::Test::Car',
      validations => [
        [ make => inclusion => [qw/Toyota Tesla Ford/] ],
        [ model => length => [2, 20] ],
        [ year => numericality => { greater_than_or_equal_to => 1960 } ],
      ],
    },
  );

Instead of setting C<validations> to '1', you set it to an arrayref that contains
items each of which is an arrayref containing validations rules.

Basically this inner arrayref is anything you'd pass to C<validates> in 
L<Valiant::Validations>.

When using this form you need to set the C<for> (or C<namespace>) attribute.  This
will be used to determine the package namespace for finding locale files and
any custom validators.  Conanically this should be something that ISA or DOES
the inlined object but this is currently not enforced.

Please keep in mind that for each inlined associated object validation we
need to create a result class so that will add a bit of overhead to this
call.

B<NOTE> There's nothing to stop you from making crazy combos where the inlined
validations contradict validations on the actual object.  Redundant validations
between inlined and on class validations will result in multiple validation error
messages.

=head1 ATTRIBUTES

This validator supports the following attributes:

=head2 validations

Either 1 or an arrayref of validation rules.  If this is an arrayref you must
set C<for> (see below).  

You can use the string C<nested> instead of 1 if you find that better documents
the intent.

=head2 for / namespace

When defining an inline validation ruleset against an associated object that
does not itself have validation rules, you must set this to something that
ISA or DOES the class you are defining inline validations on.  This is not
currently strictly enforced, but this value is used to find any locale files
or custom validator classes.

=head2 validator

This contains an instance of L<Valiant::Class> or subclass.  This gets built
for you automatically if you inline object constraints using the arrayref
form of C<validations> but you could build one yourself for any super special
custom needs.  You probably will only do that for very crazy things :)

=head2 validator_class 

Defaults to L<Valiant::Class>, which value should be a subclass of.  You probably
only need this again if you are doing very custom validations.  You probably only
want do to this if there's no other idea.

=head2 validator_class_args

A hashref of args that get passed to the C<new> method of C<validator_class>.
Defaults to an empty hashref.  You might need this if you build a custom validator
class and have special arguments it needs.

=head1 SHORTCUT FORM

This validator supports the follow shortcut forms:

    validates attribute => ( object => 1, ... );

Which is the same as:

    validates attribute => (
      object => {
        validations => 1,
      }
    );

<B<Note>: you can use the 'nested' alias for '1' here if you want.

You can also specify a validation namespace this way:

    validates attribute => ( object => 'MyApp:User', ... );

Which is the same as:

    validates attribute => (
      object => {
        for => 'MyApp::User',
        validations => 1,
      }
    );

Lastly you can specify an array of validations

    validates attribute => (
      object => [
        [ make => inclusion => [qw/Toyota Tesla Ford/] ],
        [ model => length => [2, 20] ],
        [ year => numericality => { greater_than_or_equal_to => 1960 } ],
      ],
      ...,
    );

Which is the same as:

    validates attribute => (
      object => {
        validations => [
          [ make => inclusion => [qw/Toyota Tesla Ford/] ],
          [ model => length => [2, 20] ],
          [ year => numericality => { greater_than_or_equal_to => 1960 } ],
        ],
      }
    );

Although this form doesn't let you specify the C<for> value so you can't find
custom validations that way.

=head1 GLOBAL PARAMETERS

This validator supports all the standard shared parameters: C<if>, C<unless>,
C<message>, C<strict>, C<allow_undef>, C<allow_blank>.

=head1 SEE ALSO
 
L<Valiant>, L<Valiant::Validator>, L<Valiant::Validator::Each>.

=head1 AUTHOR
 
See L<Valiant>  
    
=head1 COPYRIGHT & LICENSE
 
See L<Valiant>

=cut

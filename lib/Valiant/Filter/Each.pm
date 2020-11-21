package Valiant::Filter::Each;

use Moo::Role;
use Valiant::Util 'throw_exception', 'debug';
use Scalar::Util 'blessed';

with 'Valiant::Filter';
requires 'filter_each';

has attributes => (is=>'ro', required=>1);
has model => (is=>'ro', required=>1);


sub generate_attributes {
  my ($self, $class, $attrs) = @_;
  if(ref($self->attributes) eq 'ARRAY') {
    return @{ $self->attributes };
  } elsif(ref($self->attributes) eq 'CODE') {
    return $self->attributes->($class, $attrs);
  }
}

sub filter {
  my ($self, $class, $attrs) = @_;
  foreach my $attribute ($self->generate_attributes($class, $attrs)) {
    $attrs->{$attribute} = $self->filter_each($class, $attrs, $attribute);
  }
  return $attrs;
}

1;

=head1 TITLE

Valiant::Validator::With - A Role to create custom validators

=head1 SYNOPSIS

    package Valiant::Validator::Presence;

    use Moo;
    use Valiant::I18N;

    with 'Valiant::Validator::Each';

    has required => (is=>'ro', init_arg=>undef, required=>1, default=>1 );
    has is_blank => (is=>'ro', required=>1, default=>sub {_t 'is_blank'});

    sub normalize_shortcut {
      my ($class, $arg) = @_;
      return +{} if $arg eq '1' ;
    }

    sub validate_each {
      my ($self, $record, $attribute, $value, $opts) = @_;
      if(
          not(defined $value) ||
          $value eq '' || 
          $value =~m/^\s+$/
      ) {
        $record->errors->add($attribute, $self->is_blank, $opts)
      }
    }
  
    package Local::User;

    use Moo;
    use Valiant::Validations;

    has name => (is=>'ro');
    has age => (is=>'ro);

    validates ['name', 'age'],
      Presence => 1;

=head1 DESCRIPTION

Use this role when you with to create a custom validator that will be run 
on your class attributes.  Please note
that you can also use the 'with' validator (L<Valiant::Validator::With>)
for simple custom validation needs.  Its best to use this role when you
want custom validation that is going to be shared across several classes
so the effort pays off in reuse.

Your class must provide the method C<validate_each>, which will be called
once for each attribute in the validation.

In addition to providing validation control this role also provides a
few utility method to make creating new validators easier.

=head1 ATTRIBUTES

This validator role provides the following attributes

=head2 allow_undef

If the attribute value is undef, skip validation and allow it

=head2 allow_blank

If the attribute is blank (that is its one of undef, '', or a scalar composing only
whitespace) skip validation and allow it.

=head2 if / unless

Accepts a coderef or the name of a method which executes and is expected to
return true or false.  If false we skip the validation (or true for C<unless>).
Recieves the object, the attribute name and the value to be checked as arguments.

You can set more than one value to these with an arrayref:

    if => ['is_admin', sub { ... }, 'active_account'],

=head2 message

Provide a global error message override for the constraint.  Will accept a string,
a translation tag, a reference to a string or a reference to a function.  Using
this will override the custom error message provided by the validator.

Please not that many validators also
provide error type specific messages for providing custom errors (as well as
the ability to setup your own errors in a localization file.  Using this attribute
is the easiest but probably not always your best option.

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

=head1 METHODS

This role provides the following methods.  You may wish to review the source
code of the prebuild validators for examples of usage.

=head2 options

Used to properly construct a options hashref that you should pass to any
calls to add an error.  You need this for passing special values to the translation
method or for setting overrides such as C<strict> or C<message>.

=head2 _cb_value

Quite often you wish to give your users the flexibility in providing values
to your validation fields from a callback or as a method on the underlying
object.  That way you can avoid always hardcoding your requirements or make
them subject to certain conditions.  For example you may allow users added
before a certain date to continue to use a username with few characters than
newer ones, etc.

In order to do this you can run C<_cb_value> on the actual attribute value and if
that value is a coderef it will get invoked with the object you are validating and
the instance of the validator (in case the validator instance has some useful helper
methods). In any case you should use this method to get attribute
values that are used for doing validations:

    sub validate_each {
      my ($self, $record, $attribute, $value, $options) = @_;
      my $state = $self->_cb_value($record, $self->state);
      my %opts = (%{$self->options}, %{$options||+{}});

      if($state) {
        # value must be true
        unless($value) {
          $record->errors->add($attribute, $self->is_not_true, \%opts);
        }
      } else {
        # value must be false
        if ($value) {
          $record->errors->add($attribute, $self->is_not_false, \%opts);
        }
      }
    }

=head2 _requires_one_of

Given a list of arguments will return true if at least once of them appears.
Useful for when you are writing a validator with several optional approachs
to validation and you want to make sure the user chose at least one of them.

=head1 SEE ALSO
 
L<Valiant>, L<Valiant::Validator>, L<Valiant::Validator::Each>.

=head1 AUTHOR
 
See L<Valiant>  
    
=head1 COPYRIGHT & LICENSE
 
See L<Valiant>

=cut

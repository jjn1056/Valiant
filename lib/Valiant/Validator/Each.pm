package Valiant::Validator::Each;

use Moo::Role;
use Valiant::I18N; # So that _t is available in subclasses

with 'Valiant::Validator';
requires 'validate_each';

has allow_undef => (is=>'ro', required=>1, default=>0); # Allows undef and 'not exists'
has allow_blank => (is=>'ro', required=>1, default=>0); # A string is blank if it's empty or contains whitespaces only:
has if => (is=>'ro', predicate=>'has_if');
has unless => (is=>'ro', predicate=>'has_unless');
has on => (is=>'ro', predicate=>'has_on');
has message => (is=>'ro', predicate=>'has_message');
has strict => (is=>'ro', required=>1, default=>0);
has opts => (is=>'ro', required=>1, default=>sub { +{} });
has attributes => (is=>'ro', required=>1);

# TODO maybe have a 'where' attribute which allows a callback so you can
# stick callback / coderefs all over without needed to invoke the 'with'
# validator.
#
# TODO do we need some sort of loop control, like 'stop_on_first_error' or
# something?  Is possible that notion belongs in Valiant::Validatable

sub options { 
  my $self = shift;
  my %opts = (
    %{$self->opts},
    strict => $self->strict,
    @_);

  $opts{message} = $self->message if $self->has_message;
  return \%opts;
}

sub validate {
  my ($self, $object, $options) = @_;

  # Loop over each attribute and run the validators
  ATTRIBUTE_LOOP: foreach my $attribute (@{ $self->attributes }) {
    my $value = $object->read_attribute_for_validation($attribute);
    next if $self->allow_undef && not(defined $value);
    next if $self->allow_blank && ( not(defined $value) || $value eq '' || $value =~m/^\s+$/ );

    if($self->has_if) {
      my @if = (ref($self->if)||'') eq 'ARRAY' ? @{$self->if} : ($self->if);
      foreach my $if (@if) {
        if((ref($if)||'') eq 'CODE') {
          next ATTRIBUTE_LOOP unless $if->($object, $attribute, $value);
        } else {
          if(my $method_cb = $object->can($if)) {
            next ATTRIBUTE_LOOP unless $method_cb->($object, $attribute, $value);
          } else {
            die ref($object) ." has no method '$if'";
          }
        }
      }
    }
    if($self->has_unless) {
      my @unless = (ref($self->unless)||'') eq 'ARRAY' ? @{$self->unless} : ($self->unless);
      foreach my $unless (@unless) {
        if((ref($unless)||'') eq 'CODE') {
          next ATTRIBUTE_LOOP if $unless->($object, $attribute, $value);
        } else {
          if(my $method_cb = $object->can($unless)) {
            next ATTRIBUTE_LOOP if $method_cb->($object, $attribute, $value);
          } else {
            die ref($object) ." has no method '$unless'";
          }
        }
      }
    }

    if($self->has_on) {
      my @on = ref($self->on) ? @{$self->on} : ($self->on);
      my $context = $options->{context}||'';
      my @context = ref($context) ? @$context : ($context);
      my $matches = 0;

      OUTER: foreach my $c (@context) {
        foreach my $o (@on) {
          if($c eq $o) {
            $matches = 1;
            last OUTER;
          }
        }
      }

      next unless $matches;
    }

    $self->validate_each($object, $attribute, $value, $options);
  }
}

sub _requires_one_of {
  my ($self, $args, @list) = @_;
  foreach my $arg (@list) {
    return if defined($args->{$arg});
  }
  my $list = join ', ', @list;
  die "Missing at least one of the following args ($list)";
}

sub _cb_value {
  my ($self, $object, $value) = @_;
  if((ref($value)||'') eq 'CODE') {
    return $value->($object) || die "no value";
  } else {
    return $value;
  } 
}

1;

=head1 TITLE

Valiant::Validator::With - A Role to create custom validators

=head1 SYNOPSIS

  


=head1 DESCRIPTION

Use this role when you with to create a custom validator.  Please note
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

Provide a global error message override for the constraint.  Will accept either
a string message or a translation tag.  Please not that many validators also
provide error type specific messages for providing custom errors (as well as
the ability to setup your own errors in a localization file.  Using this attribute
is the easiest but probably not always your best option.

=head2 strict

When true instead of adding a message to the errors list, will die with the
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

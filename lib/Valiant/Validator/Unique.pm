package Valiant::Validator::Unique;

use Moo;
use Valiant::I18N;

with 'Valiant::Validator::Each';

has is_not_unique_msg => (is=>'ro', required=>1, default=>sub {_t 'is_not_unique'});
has unique_method => (is=>'ro', required=>1, default=>sub {'is_unique'});

sub normalize_shortcut {
  my ($class, $arg) = @_;
  if($arg eq '1') {
    return +{};
  } else {
    return +{ unique_method => $arg };
  }
}

sub validate_each {
  my ($self, $record, $attribute, $value, $options) = @_;
  my %opts = (%{$self->options}, %{$options||+{}});
  my $is_unique = $self->unique_method;
  
  if($record->can($is_unique)) {
    $record->errors->add($attribute, $self->is_not_unique_msg, \%opts) 
      unless $record->$is_unique($attribute, $value);
  } else {
    die "Request to test uniqueness of '$attribute' for model '@{[ $record->model_name->human ]}' failed because it doesn't support the '$is_unique' method."
  }
}

1;

=head1 TITLE

Valiant::Validator::Unique - Verify that a value is unique to the record domain

=head1 SYNOPSIS

    package Local::Test::Unique;

    use Moo;
    use Valiant::Validations;

    has username => (is=>'ro');

    validates username => (unique => 1);

    sub is_unique {
      my ($self, $attribute_name, $value);
      # Some custom logic that determines if the $attribute_name (in this case the value
      # will be 'username') has a unique value (determined by $value) in a given logical
      # domain (for example a Users table in a database).
      return 0; # Return true for 'is unique' and false otherwise. In this test case we always fail.
    }

    my $object = Local::Test::Unique->new(username=>'John');
    $object->validate;

    warn $object->errors->_dump;

    $VAR1 = {
      'username' => [
         'Username choosen is not unique',
      ]
    };

=head1 DESCRIPTION

Checks a value to see if it is unique by some custom logic that your class
must provide.  By default this must be a method on your class called 'is_unique'
(althought you can change that via the 'unique_method' attribute) which will accept
the name of the attribute and its current value.  You must then provide some custom
logic which determines if that pair is unique in a given domain (such as usernames in
a User table in a database).  Method must return true for unique and false otherwise.

This validator will raise and error if you fail to provide the methods.

=head1 ATTRIBUTES

This validator supports the following attributes:

=head2 unique_method

Name of the method on your validating class which resolves the question of uniqueness.
Default is 'is_unique'.  Example:

    sub is_unique {
      my ($self, $attribute_name, $value) = @_;
      my $found = $self->result_source->resultset->find({$attribute_name=>$value});
      # If $found in table then the $value is not unique.
      return $found ? 0:1;
    }

If your class does not provide this method an exception will be thrown at runtime.

=head2 is_not_unique_msg

The error message / tag used when the value is not true.  Default is _t('is_not_unique')
which resolves in English to 'choosen is not unique'. 

=head1 SHORTCUT FORM

This validator supports the follow shortcut forms:

    validates attribute => ( unique => 1, ... );

Which is the same as:

    validates attribute => (
      unique => +{ }
    );

Not a lot of typing saved but it makes this semantically consistent with other similar
constraints.  You can also customize the unique method using a string value:

    validates attribute => ( unique => 'check_uniqueness', ... );

Which is the same as:

    validates attribute => (
      unique => +{
        unique_method => 'check_uniqueness',
      }
    );

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

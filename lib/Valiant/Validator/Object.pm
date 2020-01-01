package Valiant::Validator::Object;

use Moo;
use Valiant::I18N;

with 'Valiant::Validator::Each';

has validates => (is=>'ro', required=>1);

sub validate_each {
  my ($self, $record, $attribute, $value, $options) = @_;
  my %opts = (%{$self->options}, %{$options||{}});
  my $validates = $self->_cb_value($record, $self->validates);

  if($validates) {
    $value->validate(%opts);
    if($value->errors->size) {
      $record->errors->add($attribute, $value->errors, \%opts);
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
          validates => 1,
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

    $person->validate; # Returns false

    warn $person->errors->_dump;

    $VAR1 = {
      'name' => [
        'Name does not match the required pattern'
      ],
      'address' => {
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
      }
    };

=head1 DESCRIPTION

Runs validations on an object which is assigned as an attribute and
aggregates those errors (if any) onto the parent object.

Useful when you need to validate an object graph or nested forms.

If your nested object has a nested object it will follow all the way
down the rabbit hole  Just don't make self referential nested objects;
that's not tested and likely to end poorly.  Patches welcomed.

=head1 ATTRIBUTES

This validator supports the following attributes:

=head1 SHORTCUT FORM

This validator supports the follow shortcut forms:

    validates attribute => ( object => 1, ... );

Which is the same as:

    validates attribute => (
      object => {
        validate => 1,
      }
    );

=head1 GLOBAL PARAMETERS

This validator supports all the standard shared parameters: C<if>, C<unless>,
C<message>, C<strict>, C<allow_undef>, C<allow_blank>.

=head1 AUTHOR
 
John Napiorkowski L<email:jjnapiork@cpan.org>
  
=head1 SEE ALSO
 
L<Valiant>, L<Valiant::Validator>, L<Valiant::Validator::Each>.
    
=head1 COPYRIGHT & LICENSE
 
Copyright 2020, John Napiorkowski L<email:jjnapiork@cpan.org>
 
This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

package Valiant::Validator::Object;

use Moo;
use Valiant::I18N;

with 'Valiant::Validator::Each';

has validates => (is=>'ro', required=>1);

has isa => (is=>'ro', predicate=>'has_isa');
has does => (is=>'ro', predicate=>'has_does');
has check => (is=>'ro', predicate=>'has_check');

has not_isa => (is=>'ro', required=>1, default=>sub {_t 'not_isa'});
has not_does => (is=>'ro', required=>1, default=>sub {_t 'not_does'});
has not_check => (is=>'ro', required=>1, default=>sub {_t 'not_check'});

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

    package Local::Test::Address;

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

    package Local::Test::Person;

    use Moo;
    use Valiant::Validations;

    has name => (is=>'ro');
    has address => (is=>'ro');

    validates name => (
      length => [2,30],
      format => qr/[AZaz]+/,
    );

    validates address => (
      presence => 1,
      object => {
        isa => 'Local::Test::Person', # does, check
        validates => 1,
      }
    )

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
    };

=head1 DESCRIPTION

=head1 ATTRIBUTES

This validator supports the following attributes:

=head1 SHORTCUT FORM

This validator supports the follow shortcut forms:

    validates attribute => ( boolean => 1, ... );

Which is the same as:

    validates boolean => (
      state => 1,
    );

The negation of this also works

    validates attribute => ( boolean => 0, ... );

Which is the same as:

    validates boolean => (
      state => 0,
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

package Valiant::Validator::Numericality;

use Moo;
use Valiant::I18N;

with 'Valiant::Validator::Each';

# TODO add postive, negative /postive_or_zero, negative_or_zero

# ($value_to_test, ?$constraint_value)
our %CHECKS = (
  greater_than              => sub { $_[0] > $_[1] ? 1:0 },
  greater_than_or_equal_to  => sub { $_[0] >= $_[1] ? 1:0 },
  equal_to                  => sub { $_[0] == $_[1] ? 1:0 },
  less_than                 => sub { $_[0] < $_[1] ? 1:0 },
  less_than_or_equal_to     => sub { $_[0] <= $_[1] ? 1:0 },
  other_than                => sub { $_[0] != $_[1] ? 1:0 },
  even                      => sub { $_[0] % 2 ? 0:1 },
  odd                       => sub { $_[0] % 2 ? 1:0 },
  is_integer                => sub { $_[0]=~/\A-?[0-9]+\z/ }, # Taken from Types::Standard
  is_number                 => sub {
                              my $val = shift;
                              ($val =~ /\A[+-]?[0-9]+\z/) ||  # Taken from Types::Standard
                              ( $val =~ /\A(?:[+-]?)          # matches optional +- in the beginning
                              (?=[0-9]|\.[0-9])               # matches previous +- only if there is something like 3 or .3
                              [0-9]*                          # matches 0-9 zero or more times
                              (?:\.[0-9]+)?                   # matches optional .89 or nothing
                              (?:[Ee](?:[+-]?[0-9]+))?        # matches E1 or e1 or e-1 or e+1 etc
                              \z/x );
                            },
);

# Run these first and fail early if the choosen one fails.
my @INIT = (qw(is_integer is_number));
my %INIT; @INIT{@INIT} = delete @CHECKS{@INIT};

# Add the init_args to set the various check constraints and to allow
# someone to override individual error messages.
foreach my $attr (keys %CHECKS) {
  has $attr => (is=>'ro', predicate=>"has_${attr}");
  has "${attr}_err" => (is=>'ro', required=>1, default=>sub { _t "${attr}_err" });
}

foreach my $attr (keys %INIT) {
  has "${attr}_err" => (is=>'ro', required=>1, default=>sub { _t "${attr}_err" });
}

has only_integer => (is=>'ro', required=>1, default=>0);

sub normalize_shortcut {
  my ($class, $arg) = @_;
  return +{
    greater_than_or_equal_to => $arg->[0],
    less_than_or_equal_to => $arg->[1],
  };
}

sub validate_each {
  my ($self, $record, $attr, $value) = @_;

  if($self->only_integer) {
    unless($INIT{is_integer}->($value)) {
      $record->errors->add($attr, $self->is_integer_err, $self->options); 
      return;
    }
  } else {
    unless($INIT{is_number}->($value)) {
      $record->errors->add($attr, $self->is_number_err, $self->options); 
      return;
    }
  }

  foreach my $key (sort keys %CHECKS) {
    next unless $self->${\"has_${key}"};
    my $constraint_value = $self->$key;
    $constraint_value = $constraint_value->($record)
      if((ref($constraint_value)||'') eq 'CODE');
    $record->errors->add($attr, $self->${\"${key}_err"}, $self->options(count=>$constraint_value))
      unless $CHECKS{$key}->($value, $constraint_value);
  }
}

1;

=head1 TITLE

Valiant::Validator::Numericality - Validate numeric attributes

=head1 SYNOPSIS

    package Local::Test::Numericality;

    use Moo;
    use Valiant::Validations;

    has age => (is => 'ro');
    has equals => (is => 'ro', default => 33);

    validates age => (
      numericality => {
        only_integer => 1,
        less_than => 200,
        less_than_or_equal_to => 199,
        greater_than => 10,
        greater_than_or_equal_to => 9,
        equal_to => \&equals,
      },
    );

    validates equals => (numericality => [5, 100]);

    my $object = Local::Test::Numericality->new(age=>8, equal=>40);
    $object->validate; # Returns false

    warn $object->errors->_dump;

    $VAR1 = {
      age => [
        "Age must be equal to 40",
        "Age must be greater than 10",
        "Age must be greater than or equal to 9",
      ],
    };

=head1 DESCRIPTION

Validates that your attributes have only numeric values. By default, it will
match an optional sign followed by an integral or floating point number. To
specify that only integral numbers are allowed set C<only_integer> to true.

There's several parameters you can set to place different type of numeric
limits on the value.  There's no checks on creating non sense rules (you can
set a C<greater_than> of 10 and a C<less_than> of 5, for example) so pay
attention.

All parameter values can be either a constant or a coderef (which will get
C<$self> as as argument).  The coderef option
exists to make it easier to write dynamic checks without resorting to writing
your own custom validators.  Each value also defines a translation tag which
folows the pattern "${rule}_err" (for example the C<greater_than> rules has a
translation tag C<greater_than_err>).  You can use the C<message> parameter to
set a custom message (either a string value or a translation tag).

=head1 CONSTRAINTS

Besides an overall test for either floating point or integer numericality this
validator supports the following constraints:

=over

=item greater_than

Accepts numeric value or coderef.  Returns error message tag V<greater_than> if
the attribute value isn't greater.

=item greater_than_or_equal_to

Accepts numeric value or coderef.  Returns error message tag V<greater_than_or_equal_to_err> if
the attribute value isn't equal or greater.

=item equal_to

Accepts numeric value or coderef.  Returns error message tag V<equal_to_err> if
the attribute value isn't equal.

=item other_than

Accepts numeric value or coderef.  Returns error message tag V<other_than_err> if
the attribute value isn't different.

=item less_than

Accepts numeric value or coderef.  Returns error message tag V<less_than_err> if
the attribute value isn't less than.

=item less_than_or_equal_to

Accepts numeric value or coderef.  Returns error message tag V<less_than_or_equal_to_err> if
the attribute value isn't less than or equal.

=item even

Accepts numeric value or coderef.  Returns error message tag V<even_err> if
the attribute value isn't an even number.

=item odd

Accepts numeric value or coderef.  Returns error message tag V<odd_err> if
the attribute value isn't an odd number.

=back

=head1 SHORTCUT FORM

This validator supports the follow shortcut forms:

    validates attribute => ( numericality => [1,10], ... );

Which is the same as:

    validates attribute => (
      numericality => {
        greater_than_or_equal_to => 1,
        less_than_or_equal_to => 10,
      },
    );

If you merely wish to test for overall numericality you can use:

    validates attribute => ( numericality => +{}, ... );
 
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

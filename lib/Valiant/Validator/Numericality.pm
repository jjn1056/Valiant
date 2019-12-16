package Valiant::Validator::Numericality;

use Moo;
use Valiant::I18N;

with 'Valiant::Validator::Each';

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
  has "not_${attr}" => (is=>'ro', required=>1, default=>sub { _t "not_${attr}" });
}

foreach my $attr (keys %INIT) {
  has "not_${attr}" => (is=>'ro', required=>1, default=>sub { _t "not_${attr}" });
}

has only_integer => (is=>'ro', required=>1, default=>0);

sub BUILD {
  my ($self, $args) = @_;
  $self->_requires_one_of($args, keys %CHECKS);
}


sub validate_each {
  my ($self, $record, $attr, $value) = @_;

  if($self->only_integer) {
    unless($INIT{is_integer}->($value)) {
      $record->errors->add($attr, $self->not_is_integer, $self->options); 
      return;
    }
  } else {
    unless($INIT{is_number}->($value)) {
      $record->errors->add($attr, $self->not_is_number, $self->options); 
      return;
    }
  }

  foreach my $key (keys %CHECKS) {
    next unless $self->${\"has_${key}"};
    my $constraint_value = $self->$key;
    $constraint_value = $constraint_value->($record)
      if((ref($constraint_value)||'') eq 'CODE');
    $record->errors->add($attr, $self->${\"not_$key"}, $self->options(count=>$constraint_value))
      unless $CHECKS{$key}->($value, $constraint_value);
  }
}

1;

=head1 TITLE

Valiant::Validator::Numericality - Validate numeric attributes

=head1 SYNOPSIS


=head1 AUTHOR
 
John Napiorkowski L<email:jjnapiork@cpan.org>
  
=head1 SEE ALSO
 
L<Valiant>, L<Valiant::Validator>
    
=head1 COPYRIGHT & LICENSE
 
Copyright 2020, John Napiorkowski L<email:jjnapiork@cpan.org>
 
This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

package Valiant::Util::Exception::InvalidValidatorArgs;

use Moo;
use Data::Dumper;
extends 'Valiant::Util::Exception';

has args => (is=>'ro', required=>1);

sub _build_message {
  my ($self) = @_;
  my $string = Dumper $self->args;
  return "Arguments for a validator must be a Hashref not @{[ ref $self->args ]}.  Data: $string";
}

1;

=head1 NAME

Valiant::Util::Exception::InvalidValidatorArgs - Args passed to a Validator are invalid

=head1 SYNOPSIS

    throw_exception InvalidValidatorArgs => (args=>$args);

=head1 DESCRIPTION

A non categorized exception

=head1 ATTRIBUTES

=head2 args 

Arguments actually passed

=head1 SEE ALSO
 
L<Valiant>

=head1 AUTHOR
 
See L<Valiant>

=head1 COPYRIGHT & LICENSE
 
See L<Valiant>

=cut

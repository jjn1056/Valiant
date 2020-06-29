package Valiant::Util;

use strict;
use warnings;
 
use Module::Runtime;
use Sub::Exporter;
 
my @exports = qw(
  throw_exception debug DEBUG_FLAG
  );

Sub::Exporter::setup_exporter({
  exports => \@exports,
  groups  => { all => \@exports }
});

sub throw_exception {
  my ($class_name, @args) = @_;
  die Module::Runtime::use_module("Valiant::Exception::$class_name")
    ->new(@args);
}

sub DEBUG_FLAG { $ENV{VALIANT_DEBUG} ? 1:0 }

sub debug {
  my ($level, @args) = @_;
  return unless exists $ENV{VALIANT_DEBUG};
  warn "@args\n" if $ENV{VALIANT_DEBUG}  >= $level;
}


1;

=head1 TITLE

Valiant::Util - Importable utility methods;

=head1 SYNOPSIS

    use Valiant::Util 'throw_exception';

    throw_exception 'MissingMethod' => (object=>$self, method=>'if');

=head1 DESCRIPTION

Just a place to stick various utility functions that are cross cutting concerns.

=head1 SUBROUTINES 

This package has the following subroutines for EXPORT

=head2 debug

  debug $level, 'message';

Send debuggin info to STDERR if $level is greater or equal to the current log level
(default log level is '0' or 'no logging').

=head2 throw_exception

    throw_exception 'MissingMethod' => (object=>$self, method=>'if');

Used to encapsulate exception types.  Maybe someday we can do continuations instead :)

=head1 SEE ALSO
 
L<Valiant>

=head1 AUTHOR
 
See L<Valiant>

=head1 COPYRIGHT & LICENSE
 
See L<Valiant>

=cut

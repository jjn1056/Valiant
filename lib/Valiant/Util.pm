package Valiant::Util;

use strict;
use warnings;
 
use Module::Runtime;
use Sub::Exporter;
 
my @exports = qw(
  throw_exception
  );

Sub::Exporter::setup_exporter({
  exports => \@exports,
  groups  => { all => \@exports }
});

sub throw_exception {
  my ($class_name, @args = @_;
  die Module::Runtime::use_module("Valiant::Exception::$class_name")
    ->new(@args);
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

package Valiant::Validator;

use Moo::Role;

requires 'validate';

1;

=head1 TITLE

Valiant::Validator - A role to define the validator interface.

=head1 SYNOPSIS

    package MySpecialValidator;

    use Moo;
    with 'Valiant::Validator';

    sub validate {
      my ($self, $object, $options) = @_;
      # DO your custom validation here.  Remember if you want to support
      # strict and message you should pass $options to any errors:
      # $object->errors->add('_base', 'Invalid', $options);
      # This method doesn't have to return anything in particular.
    }

=head1 DESCRIPTION

This is a base role for defining a validator.  This should be a class that
defines a C<validate> method. Here's a more detailed example that shows
using a custom validator with a validatable object:

    package Local::Test::Validator::Box;

    use Moo;
    with 'Valiant::Validator';

    has max_size => (is=>'ro', required=>1);

    sub validate {
      my ($self, $record, $opts) = @_;
      my $size = $record->height + $record->width + $record->length;
      if($size > $self->max_size) {
        $record->errors->add(_base=>"Total of all size cannot exceed ${\$self->max_size}", $opts),
      }
    }

    package Local::Test::Box;

    use Moo;
    use Valiant::Validations;

    has [qw(height width length)] => (is=>'ro', required=>1);

    validates [qw(height width length)] => (numericality=>+{});

    validates_with 'Box', max_size=>25;
    validates_with 'Box', max_size=>50, on=>'big', message=>'Big for Big!!';
    validates_with 'Box', max_size=>30, on=>'big', if=>'is_very_tall';

    sub is_very_tall {
      my ($self) = @_;
      return $self->height > 30 ? 1:0;
    }

When used with C<validates_with> we filter any extra arguments outside the globals
(C<on>, C<if/unless>, C<message>, C<strict>) and pass them as init args when creating
the validator.

A Validator is created once when the class uses it and exists for the full life cycle
of the validatable object.

=head1 AUTHOR
 
John Napiorkowski L<email:jjnapiork@cpan.org>
  
=head1 SEE ALSO
 
L<Valiant>, L<Valiant::Validator::Each>.
    
=head1 COPYRIGHT & LICENSE
 
Copyright 2020, John Napiorkowski L<email:jjnapiork@cpan.org>
 
This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

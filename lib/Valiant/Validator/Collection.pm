package Valiant::Validator::Collection;

use Moo;

with 'Valiant::Validator';

has if => (is=>'ro', predicate=>'has_if');
has unless => (is=>'ro', predicate=>'has_unless');
has on => (is=>'ro', predicate=>'has_on');
has message => (is=>'ro', predicate=>'has_message');
has strict => (is=>'ro', predicate=>'has_strict');
has validators => (is=>'ro', required=>1);

sub options { 
  my $self = shift;
  my %opts = (@_);
  $opts{strict} = $self->strict if $self->has_strict;
  $opts{message} = $self->message if $self->has_message;
  return \%opts;
}

sub validate {
  my ($self, $object, $options) = @_;

  if($self->has_if) {
    my $if = $self->if;
    if((ref($if)||'') eq 'CODE') {
      return unless $if->($object);
    } else {
      if(my $method_cb = $object->can($if)) {
        return unless $method_cb->($object);
      } else {
        die ref($object) ." has no method '$if'";
      }
    }
  }

  if($self->has_unless) {
    my $unless = $self->unless;
    if((ref($unless)||'') eq 'CODE') {
      return if $unless->($object);
    } else {
      if(my $method_cb = $object->can($unless)) {
        return if $method_cb->($object);
      } else {
        die ref($object) ." has no method '$unless'";
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
    return unless $matches;
  }

  foreach my $validator (@{ $self->validators }) {
    $validator->validate($object, $self->options(%$options));
  }
}

1;

=head1 TITLE

Valiant::Validator::Collection - A validator that contains and runs other validators

=head1 SYNOPSIS

    NA

=head1 DESCRIPTION

This is used internally by L<Valiant> and I can't imagine a good use for it elsewhere
so the documentation here is light.  There's no reason to NOT use it if for some
reason a good use comes to mind (I don't plan to change this so you can consider it
public API but just perhaps tricky bits for very advanced use cases).

=head1 ATTRIBUTES

This validator role provides the following attributes

=head2 if / unless

Accepts a coderef or the name of a method which executes and is expected to
return true or false.  If false we skip the validation (or true for C<unless>).
Recieves the object, the attribute name and the value to be checked as arguments.

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
under which the validation is executed.

=head1 METHODS

This role provides the following methods.  You may wish to review the source
code of the prebuild validators for examples of usage.

=head2 options

Used to properly construct a options hashref that you should pass to any
calls to add an error.  You need this for passing special values to the translation
method or for setting overrides such as C<strict> or C<message>.

=head1 AUTHOR
 
John Napiorkowski L<email:jjnapiork@cpan.org>
  
=head1 SEE ALSO
 
L<Valiant>, L<Valiant::Validator>, L<Valiant::Validator::Each>.
    
=head1 COPYRIGHT & LICENSE
 
Copyright 2020, John Napiorkowski L<email:jjnapiork@cpan.org>
 
This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

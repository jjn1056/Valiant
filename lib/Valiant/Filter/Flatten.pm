package Valiant::Filter::Flatten;

use Moo;

with 'Valiant::Filter::Each';

has pick => (is=>'ro', predicate=>'has_pick');
has join => (is=>'ro', predicate=>'has_join');
has sprintf => (is=>'ro', predicate=>'has_sprintf');

sub normalize_shortcut {
  my ($class, $arg) = @_;
  return +{ };
}

sub filter_each {
  my ($self, $class, $attrs, $attribute_name) = @_;
  my $value = $attrs->{$attribute_name};

  if($self->has_pick) {
    return $value->[0] if $self->pick eq 'first';
    return $value->[-1] if $self->pick eq 'last';
    die '"pick" must be either "first" or "last"';
  }
  if($self->has_join) {
    return join($self->join, @$value);
  }
  if($self->has_sprintf) {
    return sprintf($self->sprintf, @$value);
  }
  die 'Flatten filter must define one of pick, join or sprintf';
}

1;

=head1 TITLE

Valiant::Filter::Flatten - Array to string

=head1 SYNOPSIS

    package Local::Test::User;

    use Moo;
    use Valiant::Filters;

    has 'pick_first' => (is=>'ro', required=>1);
    has 'pick_last' => (is=>'ro', required=>1);
    has 'join' => (is=>'ro', required=>1);
    has 'sprintf' => (is=>'ro', required=>1);

    filters pick_first =>  (flatten=>+{pick=>'first'});
    filters pick_last =>  (flatten=>+{pick=>'last'});
    filters join =>  (flatten=>+{join=>','});
    filters sprintf =>  (flatten=>+{sprintf=>'%s-%s-%s'});

    my $user = Local::Test::User->new(
      pick_first => [1,2,3],
      pick_last => [1,2,3],
      join => [1,2,3],
      sprintf => [1,2,3],
    );

    print $user->pick_first;  # 1
    print $user->pick_last;   # 3
    print $user->join;        # '1,2,3'
    print $user->sprintf;     # '1-2-3'

=head1 DESCRIPTION

Given an arrayref for a value, flatten to a string in various ways

=head1 ATTRIBUTES

This filter defines the following attributes

=head2 pick

Value of either 'first' or 'last' which indicates choosing either the first or
last index of the arrayref.

=head2 join

Join the arrayref into a string using the value of 'join' as the deliminator

=head2 sprintf

Use C<sprintf> formatted string to convert an arrayref.

=head1 SEE ALSO
 
L<Valiant>, L<Valiant::Filter>, L<Valiant::Validator::Filter>.

=head1 AUTHOR
 
See L<Valiant>  
    
=head1 COPYRIGHT & LICENSE
 
See L<Valiant>

=cut

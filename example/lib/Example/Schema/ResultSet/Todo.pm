package Example::Schema::ResultSet::Todo;

use Example::Syntax;
use base 'Example::Schema::ResultSet';

__PACKAGE__->mk_group_accessors('simple' => qw/status/);

sub completed($self) {
  my $completed = $self->search_rs({status=>'completed'});
  $completed->status('completed');
  return $completed;
}

sub active($self) {
  my $active = $self->search_rs({status=>'active'});
  $active->status('active');
  return $active;
}

1;

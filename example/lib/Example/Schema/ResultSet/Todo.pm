package Example::Schema::ResultSet::Todo;

use Example::Syntax;
use base 'Example::Schema::ResultSet';

sub newer_first($self) {
  return $self->search_rs({},{order_by=>{-desc=>'id'}});
}

sub filter_by_status($self, $status) {
  return $self->search_rs({status=>$status});
}

1;

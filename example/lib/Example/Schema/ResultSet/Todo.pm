package Example::Schema::ResultSet::Todo;

use Example::Syntax;
use base 'Example::Schema::ResultSet';

sub available($self) {
  return $self->search_rs({status=>{'!='=>'archived'}});
}
sub newer_first($self) {
  return $self->search_rs({},{order_by=>{-desc=>'id'}});
}

sub filter_by_request($self, $request) {
  my $todos = $request->status_all ?
    $self : $self->search_rs({status=>$request->status});
  return $todos = $todos->set_page_or_last($request->page);  
}

1;

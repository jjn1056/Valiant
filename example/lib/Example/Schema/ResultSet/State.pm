package Example::Schema::ResultSet::State;

use Example::Syntax;
use base 'Example::Schema::ResultSet';

sub as_select_options($self) {
  return my $rs = $self
    ->search_rs(
      {},
      { columns => [ {value=>'id'}, {label=>'name'} ] }
    );
}

1;

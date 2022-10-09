package Example::Schema::ResultSet::Employment;

use Example::Syntax;
use base 'Example::Schema::ResultSet';

sub as_radio_options($self) {
  return my $rs = $self
    ->search_rs(
      {},
      { columns => [ {value=>'id'}, {label=>'label'} ] }
    );
}

1;

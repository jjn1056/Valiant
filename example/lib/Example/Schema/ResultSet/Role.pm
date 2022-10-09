package Example::Schema::ResultSet::Role;

use Example::Syntax;
use base 'Example::Schema::ResultSet';

sub as_checkbox_options($self) {
  return my $rs = $self
    ->search_rs(
      {},
      { columns => [ {value=>'id'}, {label=>'label'} ] }
    );
}

1;

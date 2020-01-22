package MyApp::Schema::Result::Person;

use strict;
use warnings;

use base 'MyApp::Schema::Result';

__PACKAGE__->table("person");
__PACKAGE__->load_components(qw/EncodedColumn /);

__PACKAGE__->add_columns(
  id => { data_type => 'bigserial', is_nullable => 0, is_auto_increment => 1 },
  username => { data_type => 'varchar', is_nullable => 0, size => 48 },
  password => {
    data_type => 'varchar',
    is_nullable => 0,
    size => 64,
    encode_column => 1,
    encode_class  => 'Digest',
    encode_args   => { algorithm => 'MD5', format => 'base64' },
  },
);

__PACKAGE__->set_primary_key("id");

1;

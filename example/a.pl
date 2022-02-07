use warnings;
use strict;

my $load_JSON = sub { require JSON };

$load_JSON->();

print JSON->new->encode({a=>1});


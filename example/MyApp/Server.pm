use warnings;
use strict;

package MyApp::Server;

use Plack::Runner;
use Module::Runtime 'use_module';

sub run { Plack::Runner->run(@_, use_module('MyApp')->to_app) }

return caller(1) ? 1 : run(@ARGV);

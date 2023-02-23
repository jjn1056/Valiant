use Test::Most;
use Valiant::HTML::Util::View;

ok my $view = Valiant::HTML::Util::View->new(aaa=>1,bbb=>2);
is $view->read_attribute_for_view('aaa'), 1;
is $view->read_attribute_for_view('bbb'), 2;



done_testing;

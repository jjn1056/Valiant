use Test::Most;
use Test::Lib;
use Local::HTML;

my $registry = Local::HTML->new;
ok $registry->add(Hello => +{class=>'Local::HTML::Hello'});
ok $registry->add(Page => +{class=>'Local::HTML::Page'});
ok $registry->add(Layout => +{class=>'Local::HTML::Layout'});

warn $registry->create(Page => +{name=>'John'})->render;

done_testing;

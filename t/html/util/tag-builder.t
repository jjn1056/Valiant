use Test::Most;
use Valiant::HTML::Util::TagBuilder;
use Valiant::HTML::Util::View;

ok my $view = Valiant::HTML::Util::View->new(aaa=>1,bbb=>2);
ok my $tb = Valiant::HTML::Util::TagBuilder->new(view=>$view);

is $tb->tag('hr'), '<hr/>';
is $tb->tag('hr', +{id=>'foo', class=>'bar', required=>1}), '<hr class="bar" id="foo" required/>';
is $tb->tag('hr', +{id=>'foo', class=>['foo', 'bar'], data=>{aa=>1, bb=>2}, required=>1}), '<hr class="foo bar" data-aa="1" data-bb="2" id="foo" required/>';

is $tb->tag('hr', +{id=>'foo', data=>{user_id=>100, locator=>'main'}}), '<hr data-locator="main" data-user-id="100" id="foo"/>';
is $tb->tag('img', +{value=>'</img><script>evilshit</script'}), '<img value="&lt;/img&gt;&lt;script&gt;evilshit&lt;/script"/>';

ok my $block = $tb->content_tag(div => +{id=>'top'}, sub {
  $tb->tag('hr'),
  "Content with evil <a href>aaa</a>",
  $tb->tag('input', +{type=>'text', name=>'user'}),
  $tb->content_tag(div => +{id=>'inner'}, sub { "stuff" }),
});

is $block, '<div id="top"><hr/>Content with evil &lt;a href&gt;aaa&lt;/a&gt;<input name="user" type="text"/><div id="inner">stuff</div></div>';
is $tb->content_tag('a', 'the link<script>evil</script>', +{href=>'a.html'}), '<a href="a.html">the link&lt;script&gt;evil&lt;/script&gt;</a>';
is $tb->join_tags($tb->content_tag(a => 'link1'), $tb->content_tag(a => 'link2')), '<a>link1</a><a>link2</a>';
is $tb->join_tags( $tb->tag('hr'), $tb->tag('hr')), '<hr/><hr/>';

is $tb->tags->hr({id=>'top'}), '<hr id="top"/>';
is $tb->tags->hr(), '<hr/>';
is $tb->join_tags($tb->tags->hr({id=>'top'}), $tb->tags->input({name=>'bb'})), '<hr id="top"/><input name="bb"/>';
is $tb->tags->div(), '<div></div>';
is $tb->tags->div("stuff"), '<div>stuff</div>';
is $tb->tags->div("stuff", "more stuff"), '<div>stuff</div>';
is $tb->tags->div({id=>1},"<a>stuff"), '<div id="1">&lt;a&gt;stuff</div>';
is $tb->tags->div({id=>1}, sub { 'stuff'}), '<div id="1">stuff</div>';

is $tb->join_tags($tb->tags->hr, $tb->tag('hr'), $tb->tag('hr')), '<hr/><hr/><hr/>';
is $tb->text('a','b', 'c'), 'abc';
is $tb->safe($tb->text('a','b')), 'ab';
is $tb->safe($tb->tag('hr', +{id=>1})), '<hr id="1"/>';
is $tb->tags->a(sub {$tb->tags->hr, 'text'}), '<a><hr/>text</a>';

is ref($tb->tag('hr')), 'Valiant::HTML::SafeString';
is ref($tb->content_tag(a => 'link')), 'Valiant::HTML::SafeString';
is ref($tb->tags->hr), 'Valiant::HTML::SafeString';
is ref($tb->tags->a(sub {$tb->tags->hr, 'text'})), 'Valiant::HTML::SafeString';

done_testing;

use Test::Most;
use Valiant::HTML::FormTags ':all';

ok 1;

warn Valiant::HTML::FormTags::_sanitize_name_to_id('a-n%$#s.sSS!1:1_1');

warn tag input => +{ data=>+{aaa=>1, bbb=>2}, id=>'mytag' };
warn tag 'input', +{ value=>'<a href>aa</a>'};
warn tag 'input', +{ value=>raw('<a href>aa</a>')};
warn tag input => +{ class=>'ok', class=>'form', id=>'mytag' };

warn content_tag 'button', 'Press Here';
warn content_tag 'button', +{ class=>['fff', '111'] }, sub { 'Press Here' };
warn content_tag 'div', +{ class=>'divclass', id=>'one' }, sub { 'test content <a href>aa</a>' };

warn input_tag 'username', undef, +{class=>'aaa'};
warn input_tag +{class=>'aaa'};
warn input_tag 'test', 'holiday <a href>aa</a>', class=>'form-input';

warn button_tag 'hello';
warn button_tag 'hello' => {id=>123123};
warn button_tag sub { 'butttttton' };
warn button_tag {id=>123123}, sub { 'butttttton' };

warn checkbox_tag 'ggg';
warn checkbox_tag 'ggg', +{class=>[1,2,3]};

warn fieldset_tag 'Info<a href="">click</a>', sub {
  input_tag 'username', undef, +{class=>'aaa'};
};

warn form_tag '/user', +{ method=>'GET' };
warn form_tag '/user', +{ class=>'form' }, sub {
  input_tag 'person[1]username', undef, +{class=>'aaa'};
};

warn label_tag 'name';
warn label_tag 'name', +{ class=>'fff' };
warn label_tag +{ class=>'fff', for=>'user' }, sub {
  'test';
};

warn form_tag '/user', +{ class=>'form' }, sub {
  radio_button_tag('role', 'admin', 0, +{ class=>'radio' }) .
  radio_button_tag('role', 'user', 1, +{ class=>'radio' });
};

warn text_area_tag "user", "hello";
warn text_area_tag "user", "hello", +{ class=>['111', 'aaa'] };

warn submit_tag;
warn submit_tag 'person';
warn submit_tag 'Save', +{name=>'person'};

warn select_tag "people", raw("<option>David</option>");
warn select_tag "people", raw("<option>David</option>"), +{include_blank=>1};
warn select_tag "people", raw("<option>David</option>"), +{include_blank=>'empty'};
warn select_tag "prompt", raw("<option>David-prompt</option>"), +{prompt=>'empty-prompt', class=>'foo'};

warn options_for_select(['A','B','C'])->to_string;
warn options_for_select([['A'=>'aa',+{id=>'fff'}],['B' =>'bb'],['C',{class=>['a','b']}]])->to_string;
warn select_tag "state", options_for_select(['A','B','C'], 'A'), +{include_blank=>1};
warn select_tag "state", options_for_select([ ['A'=>'aaa'],'B','C'], ['aaa','C']);

done_testing;

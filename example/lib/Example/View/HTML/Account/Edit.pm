package Example::View::HTML::Account::Edit;

use Moo;
use Example::Syntax;
use Example::View::HTML
  -tags => qw(div a fieldset legend br form_for script),
  -util => qw(path user),
  -views => 'HTML::Page', 'HTML::Navbar' ,'HTML::Account::Form';

has 'account' => ( is=>'ro', required=>1 );

sub render($self, $c) {
  return html_page page_title=>'Homepage', sub($page) {
    $page->add_script('/static/remote.js');
    return html_navbar active_link=>'/account',
    div {class=>"col-5 mx-auto"},
      html_account_form account=>$self->account;
  };
}

1;
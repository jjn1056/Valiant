package Example::View::HTML::Contacts::List;

use Moo;
use Example::Syntax;
use Example::View::HTML
  -tags => qw(link_to div a fieldset legend br b u button pager_for form_for table thead tbody tfoot trow th td link_to),
  -helpers => qw(edit_uri build_uri list_uri $sf),
  -views => 'HTML::Page', 'HTML::Navbar';

has 'list' => (is=>'ro', required=>1);

sub render($self, $c) {
  html_page page_title=>'Contact List', sub($page) {
    html_navbar active_link=>'contact_list',
      div {class=>"col-5 mx-auto"}, [
        legend 'Contact List',
        pager_for 'list', sub ($self, $pg, $list) {
          $pg->window_info,
          table +{ class=>'table table-striped table-bordered' }, [
            thead
              trow [
                th +{ scope=>"col" }, 'Name',
              ],
            tbody { repeat=>$list }, sub ($self, $item, $idx) {
              trow [
                td link_to edit_uri($item), $item->$sf('{:first_name} {:last_name}'),
              ],
            },
            tfoot,
              td {colspan=>2, style=>'background:white'},
                $pg->navigation_line,
          ]
        }, sub ($self, $list) {
          div { class=>"alert alert-warning", role=>"alert" },
            "There are no contacts to display."
        },

        a { href=>build_uri(), role=>'button', class=>'btn btn-lg btn-primary btn-block' },
          "Create a new Contact",
     ],
  };
}

1;

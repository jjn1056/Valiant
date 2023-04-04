package Example::View::HTML::Contacts;

use Moo;
use Example::Syntax;
use Example::View::HTML
  -tags => qw(div a fieldset legend br b u button form_for table thead tbody tfoot trow th td link_to),
  -util => qw(path $sf),
  -views => 'HTML::Layout', 'HTML::Navbar';

has 'list' => (is=>'ro', required=>1, handles=>['pager']);
has 'child_controller' => (is=>'ro', required=>1);

sub render($self, $c) {
  html_layout page_title=>'Contact List', sub($layout) {
    html_navbar active_link=>'/contacts',
      div { style=>'width: 35em; margin:auto' }, [
        legend 'Contact List',
        $self->page_window_info,
        table +{ class=>'table table-striped table-bordered' }, [
          thead
            trow [
              th +{ scope=>"col" }, 'Name',
            ],
          tbody { repeat=>$self->list }, sub ($item, $idx) {
            trow [
              td a +{ href=>$self->child_link('show_edit', [$item->id]) }, $item->$sf('{:first_name} {:last_name}'),
            ],
          },
          tfoot { cond=>$self->pager->last_page > 1  },
            td {colspan=>2, style=>'background:white'},
              ["Page: ", $self->pagelist ],
        ],
        a { href=>path('new'), role=>'button', class=>'btn btn-lg btn-primary btn-block' }, "Create a new Contact",
     ],
  };
}

sub child_link :Renders ($self, $action_name, @args) {
  return path( $self->child_controller->action_for($action_name), @args);
}

sub page_window_info :Renders ($self) {
  return '' unless $self->pager->total_entries > 0;
  my $message = $self->pager->last_page == 1 ?
    "@{[ $self->pager->total_entries ]} @{[ $self->pager->total_entries > 1 ? 'todos':'todo' ]}" :
    $self->pager->$sf('{:first} to {:last} of {:total_entries}');
  return div {style=>'text-align:center; margin-top:0; margin-bottom: .5rem'}, $message;
}

sub pagelist :Renders ($self) {
  my @page_html = ();
  foreach my $page (1..$self->pager->last_page) {
    push @page_html, a {href=>path('list', +{page=>$page}), style=>'margin: .5rem'},
      $page == $self->pager->current_page ? b u $page : $page;
  }
  return @page_html;
}

1;

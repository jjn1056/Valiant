package Example::View::HTML::Todos;

use Moo;
use Example::Syntax;
use Valiant::HTML::TagBuilder 'div', 'fieldset', 'table', 'thead','trow', 'tbody', 'tfoot', 'td', 'th', 'a', 'b', 'u', 'span', ':utils';

extends 'Example::View::HTML';

has 'list' => (is=>'ro', required=>1, handles=>[qw/pager status/]);
has 'todo' => (is=>'ro', required=>1 );

__PACKAGE__->views(
  layout => 'HTML::Layout',
  navbar => 'HTML::Navbar',
  form => 'HTML::Form',
);

sub render($self, $c) {
  $self->layout(page_title=>'Todo List', sub($layout) {
    $self->navbar(active_link=>'/todos'),
    $self->form($self->todo, +{style=>'width:35em; margin:auto'}, sub ($fb, $todo) {
      fieldset [
        $fb->legend,
        $fb->model_errors,

        $self->last_page_warning,
        $self->page_window_info,

        table +{class=>'table table-striped table-bordered', style=>'margin-bottom:0.5rem'}, [
          thead
            trow [
              th +{scope=>"col"},'Title',
              th +{scope=>"col", style=>'width:8em'}, 'Status',
            ],
          tbody { repeat=>$self->list }, sub ($todo, $i) {
            trow [
             td a +{ href=>"/todos/@{[ $todo->id ]}" }, $todo->title,
             td $todo->status,
            ],
          },
          tfoot { cond=>$self->pager->last_page > 1  },
            td {colspan=>2, style=>'background:white'},
              ["Page: ", $self->pagelist ],
        ],
        
        $self->status_filter_box,

        div +{ class=>'form-group' }, [
          $fb->input('title', +{ class=>'form-control', placeholder=>'What needs to be done?', errors_classes=>'is-invalid' }),
          $fb->errors_for('title', +{ class=>'invalid-feedback' }),
        ],
        $fb->submit('Add Todo to List', +{class=>'btn btn-lg btn-primary btn-block'}),
      ],
    }),
  });
}

sub last_page_warning($self) {
  div { cond=> $self->pager->current_page > $self->pager->last_page, class=>'alert alert-warning', role=>'alert' },
    "The selected page is greater than the total number of pages available.  Showing the last page.",
}

sub page_window_info($self) {
  return '' unless $self->pager->total_entries > 0;
  my $message = $self->pager->last_page == 1 ?
    "@{[ $self->pager->total_entries ]} @{[ $self->pager->total_entries > 1 ? 'todos':'todo' ]}" :
    "@{[ $self->pager->first]} to @{[ $self->pager->last ]} of @{[ $self->pager->total_entries ]}";

  return div {style=>'text-align:center; margin-top:0; margin-bottom: .5rem'}, $message;
}

sub pagelist($self) {
  my @page_html = ();
  foreach my $page (1..$self->pager->last_page) {
    my $query = "?page=${page};status=@{[ $self->status ]}";
    push @page_html, a {href=>$query, style=>'margin: .5rem'}, $page == $self->pager->current_page ? b u $page : $page;
  }
  return @page_html;
}

sub status_filter_box($self) {
  div {style=>'text-align:center; margin-bottom: 1rem'}, [
    map { $self->status_link($_) } qw/all active completed/,
  ];
}

sub status_link($self, $status) {
  my @label = $self->status_label($status);
  return span {style=>'margin: .5rem'}, \@label if $self->status eq $status;
  return a { href=>"?status=$status;page=1", style=>'margin: .5rem'}, \@label;
}


sub status_label($self, $status) {
  return b u $status if $status eq $self->status;
  return $status;
}

1;

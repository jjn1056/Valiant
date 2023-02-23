package Valiant::HTML::Util::TagBuilder;

use Moo;
use Sub::Util;
use Scalar::Util;
use overload 
  bool => sub {1}, 
  '""' => sub { shift->to_string },
  fallback => 1;

our $ATTRIBUTE_SEPARATOR = ' ';
our %SUBHASH_ATTRIBUTES = map { $_ => 1} qw(data aria);
our %ARRAY_ATTRIBUTES = map { $_ => 1 } qw(class);
our %HTML_VOID_ELEMENTS = map { $_ => 1 } qw(area base br col circle embed hr img input keygen link meta param source track wbr);
our %BOOLEAN_ATTRIBUTES = map { $_ => 1 } qw(
  allowfullscreen allowpaymentrequest async autofocus autoplay checked compact controls declare default
  defaultchecked defaultmuted defaultselected defer disabled enabled formnovalidate hidden indeterminate
  inert ismap itemscope loop multiple muted nohref nomodule noresize noshade novalidate nowrap open
  pauseonexit playsinline readonly required reversed scoped seamless selected sortable truespeed
  typemustmatch visible);

our %HTML_CONTENT_ELEMENTS = map { $_ => 1 } qw(
  a abbr acronym address apple article aside audio
  b basefont bdi bdo big blockquote body button
  canvas caption center cite code colgroup
  data datalist dd del details dfn dialog dir div dl dt
  em
  fieldset figcaption figure font footer form frame frameset
  head header hgroup h1 h2 h3 h4 5 h6 html
  i iframe ins
  kbd label legend li
  main map mark menu menuitem meter
  nav noframes noscript
  object ol optgroup option output
  p picture pre progress
  q
  rp rt ruby
  s samp script section select small span strike strong style sub summary sup svg
  table tbody td template textarea tfoot th thead time title  tt tr
  u ul
  var video);

has view => (
  is => 'bare',
  required => 1,
  handles => [qw(safe raw escape_html safe_concat read_attribute_for_view)],
);

sub import { shift->_install_tags }

sub _install_tags {
  my $class = shift;

  foreach my $e (keys %HTML_VOID_ELEMENTS) {
    my $full_name = $class . "::_tags::$e";
    no strict 'refs';
    *$full_name = Sub::Util::set_subname $full_name => sub {
      my ($self, $attrs) = @_;
      $attrs = +{} unless $attrs;

      return $self->{tb}->tag($e, $attrs);
    };
  }

  foreach my $e (keys %HTML_CONTENT_ELEMENTS) {
    my $full_name = $class . "::_tags::$e";
    no strict 'refs';
    *$full_name = Sub::Util::set_subname $full_name => sub {
      my $self = shift;
      my $attrs = ((ref($_[0])||'') eq 'HASH') ? shift : +{};
      my $content = shift;
      my @args = ((ref($content)||'') eq 'CODE') ?
        ($e, $attrs, $content) :
          ($e, $content, $attrs);

      return $self->{tb}->content_tag(@args);
    };
  }

}

sub tags {
  my $self = shift;
  my $class = ref $self;
  return bless +{ tb=>$self }, "${class}::_tags";
}

sub to_string { return shift->{tag_info} || '' }

sub tag {
  my ($self, $name, $attrs) = (@_, +{});  
  die "'$name' is not a valid VOID HTML element" unless $HTML_VOID_ELEMENTS{$name};
  return my $tag = $self->raw("<${name}@{[ $self->_tag_options(%{$attrs}) ]}/>");
}

sub content_tag {
  my $self = shift;
  my $name = shift;
  die "'$name' is not a valid HTML content element" unless $HTML_CONTENT_ELEMENTS{$name};

  my $block = ref($_[-1]) eq 'CODE' ? pop(@_) : undef;
  my $attrs = ref($_[-1]) eq 'HASH' ? pop(@_) : +{};
  my @content = defined($block) ? $block->($self) : (shift || '');
  my $content = $self->safe_concat(@content);
  return my $tag = $self->raw("<${name}@{[ $self->_tag_options(%{$attrs}) ]}>${content}</${name}>");
}

sub join_tags {
  my $self = shift;
  return $self->safe_concat(@_);
}

sub text { return shift->safe_concat(@_) }

sub _tag_options {
  my $self = shift;
  my (%attrs) = @_;
  return '' unless %attrs;
  my @attrs = ('');
  foreach my $attr (sort keys %attrs) {
    if($BOOLEAN_ATTRIBUTES{$attr}) {
      push @attrs, $attr if $attrs{$attr};
    } elsif($SUBHASH_ATTRIBUTES{$attr}) {
      foreach my $subkey (sort keys %{$attrs{$attr}}) {
        push @attrs, $self->_tag_option("${attr}-@{[ _dasherize($subkey) ]}", $attrs{$attr}{$subkey});
      }
    } elsif($ARRAY_ATTRIBUTES{$attr}) {
      my $class = ((ref($attrs{$attr})||'') eq 'ARRAY') ? join(' ', @{$attrs{$attr}}) : $attrs{$attr};
      push @attrs, $self->_tag_option($attr, $class);
    } else {
      push @attrs, $self->_tag_option($attr, $attrs{$attr});
    }
  }
  return join $ATTRIBUTE_SEPARATOR, @attrs;
}

sub _tag_option {
  my $self = shift;
  my ($attr, $value) = @_;
  return qq[${attr}="@{[ $self->escape_html(( defined($value) ? $value : '' )) ]}"];
}

sub _dasherize {
  my $value = shift;
  my $copy = $value;
  $copy =~s/_/-/g;
  return $copy;
}

package Valiant::HTML::Util::TagBuilder::_tags;

use overload 
  bool => sub {1}, 
  '""' => sub { shift->to_string },
  fallback => 1;

sub to_string {
  my $self = shift;
  return $self->{tb}->to_string;
}

sub join_tags { my $self = shift; $self->{tb}->join_tags(@_); return $self }
sub text { my $self = shift; $self->{tb}->text(@_); return $self }
sub tag { my $self = shift; $self->{tb}->tag(@_); return $self }
sub content_tag { my $self = shift; $self->{tb}->content_tag(@_); return $self }

1;


=head1 NAME

Valiant::HTML::Util::TagBuilder - Utility class to generate HTML tags

=head1 SYNOPSIS

    use Valiant::HTML::Util::TagBuilder;
    my $tag_builder = Valiant::HTML::Util::TagBuilder->new(view => $view);
    my $tag = $tag_builder->tag('div', { class => 'container' });

=head1 DESCRIPTION

L<Valiant::HTML::Util::TagBuilder> is a utility class for generating HTML tags.  It wraps
a view or template object which must provide methods for html escaping and for marking
strings as safe for display.

=head1 ATTRIBUTES

This class has the following initialization attributes

=head2 view

Object, Required.  This should be an object that provides methods for creating escaped
strings for HTML display.  Many template systems provide a way to mark strings as safe
for display, such as L<Mojo::Template>.  You will need to add the following proxy methods
to your view / template to adapt it for use in creating safe strings.

=over

=item raw

given a string return a single tagged object which is marked as safe for display.  Do not do any HTML 
escaping on the string.  This is used when you want to pass strings straight to display and that you 
know is safe.  Be careful with this to avoid HTML injection attacks.

=item safe

given a string return a single tagged object which is marked as safe for display.  First HTML escape the
string as safe unless its already been done (no double escaping).

=item safe_concat

Same as C<safe> but instead works an an array of strings (or mix of strings and safe string objects) and
concatenates them all into one big safe marked string.

=item html_escape

Given a string return string that has been HTML escaped.

=item read_attribute_for_view

Given an attribute name return the value that the view has defined for it.  

=back

Both C<raw>, C<safe> and C<safe_concat> should return a 'tagged' object which is specific to your view or
template system. However this object must 'stringify' to the safe version of the string to be displayed.  See
L<Valiant::HTML::SafeString> for example API.  We use <Valiant::HTML::SafeString> internally to provide
safe escaping if you're view doesn't do automatic escaping, as many older template systems like Template
Toolkit.

=head1 METHODS

=head2 new

Create a new instance of the TagBuilder.

  my $tag_builder = Valiant::HTML::Util::TagBuilder->new(view => $view);

=head2 tags

Returns a reference to a blessed hash that provides shortcut methods for all HTML tags.

  my $tags = $tag_builder->tags;
  my $img_tag = $tags->img({src => '/path/to/image.jpg'});
  # <img src="/path/to/image.jpg" />
  
  my $div_tag = $tags->div({id=>'top}, "Content");
  # <div id="top">Content<div>

=head2 tag

Generates a HTML tag of the specified type and with the specified attributes.

=head2 content_tag

Generates a HTML content tag of the specified type, with the specified attributes, and with the specified content.

    my $tag = $tag_builder->content_tag('p', { class => 'lead' }, 'Lorem ipsum dolor sit amet');

The content can also be generated by a code block, as shown in the following example.

    my $tag = $tag_builder->content_tag('ul', { class => 'list-group' }, sub {
      $tag_builder->content_tag('li', 'Item 1') .
      $tag_builder->content_tag('li', 'Item 2') .
      $tag_builder->content_tag('li', 'Item 3')
    });

=head2 join_tags

Joins multiple tags together and returns them as a single string.

    my $tags = $tag_builder->join_tags(
      $tag_builder->tag('div', { class => 'container' }),
      $tag_builder->content_tag('p', 'Lorem ipsum dolor sit amet')
    );

=head2 text

Generates a safe string of text.

   my $text = $tag_builder->text('Lorem ipsum dolor sit amet');

=head2 to_string

Returns the generated HTML tag as a string.

    my $tag = $tag_builder->tag('div', { class => 'container' });
    my $tag_string = $tag->to_string;

=head1 PROXY METHODS

The following methods are proxied from the enclosed view object.  You should
refer to your view for more.

=head2 safe

=head2 raw

=head2 escape_html

=head2 safe_concat

=head2 read_attribute_for_view

=head1 AUTHOR

See L<Valiant>

=head1 SEE ALSO

L<Valiant>, L<Valiant::HTML::FormBuilder>

=head1 AUTHOR
 
See L<Valiant>

=head1 COPYRIGHT & LICENSE
 
See L<Valiant>

=cut

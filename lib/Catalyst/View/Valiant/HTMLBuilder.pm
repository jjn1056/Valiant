package Catalyst::View::Valiant::HTMLBuilder;

use Moose;
use Moo::_Utils;
use Module::Runtime;
use Valiant::HTML::SafeString;
use Valiant::HTML::Util::TagBuilder;
use Valiant::JSON::Util;
use Scalar::Util;
use Sub::Util;
use URI::Escape ();
use Carp;

extends 'Catalyst::View::BasePerRequest';

has 'caller' => (is=>'ro', required=>0, predicate=>'has_caller');

has 'tb' => (is=>'ro', required=>1, lazy=>1, builder=>'_build_tags');

  sub _build_tags {
    my $self = shift;
    return Valiant::HTML::Util::TagBuilder->new(view=>$self);
  }

has 'view_fragment' => (is=>'ro', predicate=>'has_view_fragment');

sub components { return qw/Form Pager/ }  

foreach my $component (components()) {
  my $component_method_name = lc($component);
  my $sub = Sub::Util::set_subname $component_method_name => sub {
    my $self = shift;
    return $self->{"__${component_method_name}"} ||= do {
      my $module = Module::Runtime::use_module("Catalyst::View::Valiant::HTMLBuilder::$component");
      $module->new(
        view=>$self,
        context=>$self->ctx,
        controller=>$self->ctx->controller,
      );
    };
  };
  Moo::_Utils::_install_tracked(__PACKAGE__, $component_method_name, $sub);
}

my $_SELF;
sub BUILD { $_SELF = shift }

sub import {
  my $class = shift;
  my $target = caller;
  my @args = @_;

  $target->meta->superclasses($class);
  $class->_install_helpers($target, @args);
  $class->_install_tags($target);
}

sub _install_helpers {
  my $class = shift;
  my $target = shift;
  my @args = @_;

  foreach my $helper (@args) {
    my $sub = Sub::Util::set_subname "${target}::${helper}" => sub {
      my $self = shift;
      croak "View method called without correct self" unless $self and $self->isa($target);
      return $self->form->$helper(@_) if $self->form->can($helper);
      return $self->pager->$helper(@_) if $self->pager->can($helper);
      return $self->ctx->controller->$helper(@_) if $self->ctx->controller->can($helper);
      return $self->ctx->$helper(@_) if $self->ctx->can($helper);

      croak "Can't find helper '$helper' in form, pager, controller or context";
    };
    Moo::_Utils::_install_tracked($target, $helper, $sub);
  }
}

sub _install_tags {
  my $class = shift;
  my $target = shift;
  my $tb = Module::Runtime::use_module('Valiant::HTML::Util::TagBuilder');

  my %tags = map {
    ref $_ ? @$_ : ($_ => ucfirst($_) ); # up case the tag name
  } (@Valiant::HTML::Util::TagBuilder::ALL_TAGS);
  $tags{$_} = $_ for @_;

  foreach my $tag (keys %tags) {
    my $tag_name = $tags{$tag};

    my $method;
    if(Valiant::HTML::Util::TagBuilder->is_content_tag($tag)) {
      $method = Sub::Util::set_subname "${target}::${tag_name}" => sub {
        my ($args, $content) = (+{}, '');
        $args = shift if ref $_[0] eq 'HASH';
        if(defined($_[0])) {
          if(Scalar::Util::blessed($_[0]) && $_[0]->isa($class)) {
            $content = shift->get_rendered;
          } elsif((ref($_[0])||'') eq 'ARRAY') {
            my $inner = shift;
            my @content = map {
              (Scalar::Util::blessed($_) && $_->isa($class)) ? $_->get_rendered : $_;
            } @{$inner};
            $content = $class->safe_concat(@content);
          } else {
            $content = shift;
          }
        }
        return $_SELF->tb->tags->$tag($args, $content), @_ if @_;
        return $_SELF->tb->tags->$tag($args, $content);
      };
    } elsif(Valiant::HTML::Util::TagBuilder->is_void_tag($tag)) {
      $method = Sub::Util::set_subname "${target}::${tag_name}" => sub {
        my $args = +{};
        $args = shift if ref $_[0] eq 'HASH';
        return $_SELF->tb->tags->$tag($args), @_ if @_;
        return $_SELF->tb->tags->$tag($args);
      };
    }
     Moo::_Utils::_install_tracked($target, $tag_name, $method);
  }
}

sub view {
  my $self = shift;
  my $view = shift;  
  my @args = (caller=>$self);

  push @args, %{shift()} if ((ref($_[0])||'') eq 'HASH');
  push @args, shift if ((ref($_[0])||'') eq 'CODE');

  my $view_object = $self->ctx->view($view, @args);

  return $view_object, @_ if @_;
  return $view_object;
}

sub read_attribute_for_html {
  my ($self, $attribute) = @_;
  return unless defined $attribute;
  return my $value = $self->$attribute if $self->can($attribute);
  die "No such attribute '$attribute' for view"; 
}

sub attribute_exists_for_html {
  my ($self, $attribute) = @_;
  return unless defined $attribute;
  return 1 if $self->can($attribute);
  return;
}

sub flatten_rendered {
  my ($self, @rendered) = @_;
  return $self->safe_concat(@rendered);
}

my %data_templates = ();
sub data_template {
  my $self = shift;
  my $class = ref($self) || $self;
  my $template = $data_templates{$class} ||= do {
    my $data = "${class}::DATA";
    my $template = do { local $/; <$data> };
  };

  return $self->tb->sf($self, $template, {raw=>1});
}

sub safe { shift; return Valiant::HTML::SafeString::safe(@_) }
sub raw {shift; return Valiant::HTML::SafeString::raw(@_) }
sub safe_concat { shift; return Valiant::HTML::SafeString::safe_concat(@_) }
sub escape_html { shift; return Valiant::HTML::SafeString::escape_html(@_) }
sub escape_javascript { shift; return Valiant::JSON::Util::escape_javascript(@_) }
sub escape_js { shift->escape_javascript(@_) }

sub uri_escape {
  my $self = shift;
  if(scalar(@_) > 1) {
    my %pairs = @_;
    return join '&', map { URI::Escape::uri_escape($_) . '=' . URI::Escape::uri_escape($pairs{$_}) } keys %pairs;
  } else {
    my $string = shift;
    return URI::Escape::uri_escape($string);
    
  }
}

around 'get_rendered' => sub {
  my ($orig, $self, @args) = @_;
  if($self->has_view_fragment) {
    my $method = $self->view_fragment;
    return $self->$method;
  } else {
    return $self->$orig(@args);
  }
};

__PACKAGE__->config(content_type=>'text/html');
__PACKAGE__->meta->make_immutable;

__END__

use Sub::Util;
use Valiant::HTML::SafeString ();
use Attribute::Handlers;
use Module::Runtime;
use Carp;
use Catalyst::View::Valiant::HTMLBuilder::Form;
use Catalyst::View::Valiant::HTMLBuilder::Pager;
use Valiant::JSON::Util qw();
use namespace::clean ();

extends 'Catalyst::View::BasePerRequest';

has 'caller' => (is=>'ro', required=>0, predicate=>'has_caller');
## Shared Form Object

my $form;
my $pager;

sub form_args { return () }
sub pager_args { return () }

sub _install_form {
  my $class = shift;
  my $target = shift;
  my $view = Module::Runtime::use_module('Valiant::HTML::Util::View')->new; # Placeholder
  $form = Catalyst::View::Valiant::HTMLBuilder::Form->new(view=>$view, $class->form_args);
}

sub _install_pager {
  my $class = shift;
  my $target = shift;
  my $view = Module::Runtime::use_module('Valiant::HTML::Util::View')->new; # Placeholder
  $pager = Catalyst::View::Valiant::HTMLBuilder::Pager->new(view=>$view, $class->pager_args);
}

## Code Attributes

sub Renders :ATTR(CODE) {
  my ($package, $symbol, $referent, $attr, $data) = @_;
  my $name = *{$symbol}{NAME};
  unless($package->can("__attr_${name}")) {
    my $wrapper = sub {
      my ($self, @args) = @_;
      croak "View method called without correct self" unless $self->isa($package);

      local $form->{view} = $self; # Evil Hack lol
      local $form->{context} = $self->ctx;
      local $form->{controller} = $self->ctx->controller;

      local $pager->{view} = $self; # Evil Hack lol
      local $pager->{context} = $self->ctx;
      local $pager->{controller} = $self->ctx->controller;

      return $referent->(@_);
    };
    Moo::_Utils::_install_tracked($package, "__attr_${name}", $wrapper);
    Moo::_Utils::_install_tracked($package, $name, sub {
      return $package->can("__attr_${name}")->(@_);
    });
  }
}

my %exports_by_class;

sub unimport {
  my $class = shift;
  my $target = caller;
  namespace::clean->clean_subroutines($target, @{$exports_by_class{$target}||[]});
} 

sub import {
  my $class = shift;
  my $target = caller;

  my (@tags, @views, @utils, $which) = ();
  while(@_) {
    my $next = shift;
    if($next eq '-tags') {
      $which = 'tags';
      next;
    } elsif(($next eq '-helpers') || ($next eq '-util') || ($next eq '-utils')) {
      $which = 'util';
      next;
    }

    if($which eq 'tags') {
      push @tags, $next;
    } elsif($which eq 'views') {
      my $key = $next;
      $next =~s/::/_/g;
      $next =~s/(?<=[a-z])(?=[A-Z])/_/g;
      push @views, lc($next) => $key;
    } elsif($which eq 'util') {
      push @utils, $next;
    }
  }

  Moo->_set_superclasses($target, $class);
  Moo->_maybe_reset_handlemoose($target);

  $class->_install_form($target);
  $class->_install_pager($target);
  $class->_install_tags($target, @tags);
  $class->_install_utils($target, @utils);

  $exports_by_class{$target} = [ @tags, @views, @utils ];
}

sub form { $form }
sub pager { $pager}
sub tags { $form->tags }

sub _install_utils {
  my $class = shift;
  my $target = shift;
  my @utils = (qw/user path raw safe escape_js view content content_for 
    content_append content_replace/, '$sf', @_);

  no strict 'refs';
  foreach my $util (@utils) {
    if($util eq '$sf') {
      my $sf = sub { $form->sf(@_) };
      *{"${target}::sf"} = \$sf;
    } elsif($util eq 'content') {
      Moo::_Utils::_install_tracked($target, "__content", \&{"Catalyst::View::BasePerRequest::content"});  
      my $content_sub = sub {
        if(Scalar::Util::blessed($_[0])) {
          return $target->can('__content')->(shift, shift), @_;
        } else {
          return $target->can('__content')->($form->view, shift), @_;
        }
      };
      Moo::_Utils::_install_tracked($target, 'content', $content_sub);
    } elsif( ($util eq 'content_for') || ($util eq 'content_append') || ($util eq 'content_replace') || ($util eq 'content_around') ) {
      Moo::_Utils::_install_tracked($target, "__${util}", \&{"Catalyst::View::BasePerRequest::${util}"}); 
      my $sub = sub {
        if(Scalar::Util::blessed($_[0])) {
          return $target->can("__${util}")->(shift, shift, shift), @_;
        } else {
          return $target->can("__${util}")->($form->view, shift, shift), @_;
        }
      };
      Moo::_Utils::_install_tracked($target, $util, $sub);
    } elsif(
        ($util eq 'path') || ($util eq 'safe') || ($util eq 'raw') || ($util eq 'user') ||
        ($util eq 'escape_javascript') || ($util eq 'escape_js') || ($util eq 'view') 
      ) {
      Moo::_Utils::_install_tracked($target, "__${util}", $target->can($util));
      my $sub = sub {
        if(Scalar::Util::blessed($_[0]) && $_[0]->isa('Catalyst::View::Valiant::HTMLBuilder')) {
          return $target->can("__${util}")->(@_);
        } else {
          return $target->can("__${util}")->($form->view, @_);
        }
      };
      Moo::_Utils::_install_tracked($target, ${util}, $sub);
    } else {
      ## could be from controller or context
      my $sub = sub {
        if($form->controller->can($util)) {
          return $form->controller->$util(@_);
        } elsif($form->context->can($util)) {
          return $form->context->$util(@_);
        } else {
          croak "Can't find method $util in controller or context";
        }
      };
      Moo::_Utils::_install_tracked($target, $util, $sub);
    }
  }
}

sub _install_tags {
  my $class = shift;
  my $target = shift;
  my %tags = map {
    ref $_ ? @$_ : ($_ => ucfirst($_) ); # up case the tag name
  } (@Valiant::HTML::Util::TagBuilder::ALL_TAGS);
  $tags{$_} = $_ for @_;

  foreach my $tag (keys %tags) {
    my $method;
    my $tag_name = $tags{$tag};

    if($form->is_content_tag($tag)) {
      $method = Sub::Util::set_subname "${target}::${tag_name}" => sub {
        my ($args, $content) = (+{}, '');
        $args = shift if ref $_[0] eq 'HASH';
        if(defined($_[0])) {
          if(Scalar::Util::blessed($_[0]) && $_[0]->isa($class)) {
            $content = shift->get_rendered;
          } elsif((ref($_[0])||'') eq 'ARRAY') {
            my $inner = shift;
            my @content = map {
              (Scalar::Util::blessed($_) && $_->isa($class)) ? $_->get_rendered : $_;
            } @{$inner};
            $content = $class->safe_concat(@content);
          } else {
            $content = shift;
          }
        }
        return $form->tags->$tag($args, $content), @_ if @_;
        return $form->tags->$tag($args, $content);
      };
    } elsif($form->is_void_tag($tag)) {
      $method = Sub::Util::set_subname "${target}::${tag_name}" => sub {
        my $args = +{};
        $args = shift if ref $_[0] eq 'HASH';
        return $form->tags->$tag($args), @_ if @_;
        return $form->tags->$tag($args);
      };
    }  elsif($form->can($tag)) {
      $method = Sub::Util::set_subname "${target}::${tag}" => sub {
        my @args = ();
        if($tag eq 'link_to') {
          push @args, shift(); # required uri
          if( (ref($_[0])||'') eq 'HASH' ) {
            push @args, shift(), shift(); # if arg2 is a hash, then two more args required
          } else {
            push @args, shift(); # if arg2 is not a hash, then one more arg required
          }
        }
        if($tag eq 'form_for') {
          while(@_) {
            my $element = shift;
            push @args, $element;
            last if ref($element) eq 'CODE';
          }
          return $form->$tag(@args), @_;
        }
        while(@_) {
          last if
            !defined($_[0])
            || ((Scalar::Util::blessed($_[0])||'') eq 'Valiant::HTML::SafeString')
            || (Scalar::Util::blessed($_[0]) && $_[0]->isa($class))
            || $_[0] eq '';
          push @args, shift;
          if(ref $_[0] eq 'ARRAY') {
            my $inner = shift;
            my @content = map {
              (Scalar::Util::blessed($_) && $_->isa($class)) ? $_->get_rendered : $_;
            } @{$inner};
            push @args, $class->safe_concat(@content);
          }
        }
        return $form->$tag(@args), @_; 
      };
    } elsif($pager->can($tag)) {
      $method = Sub::Util::set_subname "${target}::${tag}" => sub {
        my @args = ();
        if($tag eq 'pager_for') {
          while(@_) {
            my $element = shift;
            push @args, $element;
            last if ref($element) eq 'CODE' && (ref($_[0])||'') ne 'CODE';
          }
          return $pager->$tag(@args), @_;
        } else {
          die "pager doesn't support method $tag";
        }
      };
    } else {
      die "No such tag '$tag' for view";
    }

    # I do this dance so that the exported methods can be called as both a function
    # and as a method on the target instance.

    Moo::_Utils::_install_tracked($target, $tag_name, $method);
    Moo::_Utils::_install_tracked($target, "_tag_${tag_name}", \&{"${target}::${tag_name}"});
    Moo::_Utils::_install_tracked($target, $tag_name, sub {
      my $view = shift if Scalar::Util::blessed($_[0]) && $_[0]->isa($target);
      if($view) {
        local $form->{view} = $view if $view;
        local $form->{context} = $view->ctx if $view;
        local $form->{controller} = $view->ctx->controller if $view;

        local $pager->{view} = $view if $view;
        local $pager->{context} = $view->ctx if $view;
        local $pager->{controller} = $view->ctx->controller if $view;
      }
      return $target->can("_tag_${tag_name}")->(@_);
    });
  }
}

sub safe { shift; return Valiant::HTML::SafeString::safe(@_) }
sub raw {shift; return Valiant::HTML::SafeString::raw(@_) }
sub safe_concat { shift; return Valiant::HTML::SafeString::safe_concat(@_) }
sub escape_html { shift; return Valiant::HTML::SafeString::escape_html(@_) }
sub escape_javascript { shift; return Valiant::JSON::Util::escape_javascript(@_) }
sub escape_js { shift->escape_javascript(@_) }

sub read_attribute_for_html {
  my ($self, $attribute) = @_;
  return unless defined $attribute;
  return my $value = $self->$attribute if $self->can($attribute);
  die "No such attribute '$attribute' for view"; 
}

sub attribute_exists_for_html {
  my ($self, $attribute) = @_;
  return unless defined $attribute;
  return 1 if $self->can($attribute);
  return;
}

sub flatten_rendered {
  my ($self, @rendered) = @_;
  return $self->safe_concat(@rendered);
}

sub data_template {
  my $self = shift;
  my @args = @_ ? @_ : ($self);

  my $class = ref($self) || $self;
  my $data = "${class}::DATA";
  my $template = do { local $/; <$data> };

  if(Scalar::Util::blessed($args[0])) {
    return $form->sf(shift(@args), $template, {raw=>1});
  } else {
    return $form->sf($template, @args, {raw=>1});
  }
}

sub user { shift->ctx->user || croak 'No logged in user' }



sub path {
  my $self = shift;
  my $c = $self->ctx;
  my $action_proto = shift;
  my @args = @_;

  # already is an $action
  if(Scalar::Util::blessed($action_proto) && $action_proto->isa('Catalyst::Action')) {
    die "We can't create a URI from '$action_proto' with the given arguments"
      unless my $uri = $c->uri_for($action_proto, @args);
    return $uri;
  }

  return $action_proto if Scalar::Util::blessed($action_proto) && $action_proto->isa('URI'); # common error 
      
  # Hard error if the spec looks wrong...
  die "$action_proto is not a string" unless ref \$action_proto eq 'SCALAR';
      
  my $action;
  if($action_proto =~/^\/?\*/) {
    croak "$action_proto is not a named action"
      unless $action = $c->dispatcher->get_action_by_path($action_proto);
  } elsif($action_proto=~m/^(.*)\:(.+)$/) {
    croak "$1 is not a controller"
      unless my $controller = $c->controller($1||'');
    croak "$2 is not an action for controller ${\$controller->component_name}"
      unless $action = $controller->action_for($2);
  } elsif($action_proto =~/\//) {
    my $path = eval {
      $action_proto=~m/^\// ?
      $action_proto : 
      $c->controller->action_for($action_proto)->private_path;
    } || croak "Error: $@ while trying to get private path for $action_proto";
    croak "$action_proto is not a full or relative private action path" unless $path;
    croak "$path is not a private path" unless $action = $c->dispatcher->get_action_by_path($path);
  } elsif($action = $c->controller->action_for($action_proto)) {
    # Noop
  } else {
    # Fallback to static
    $action = $action_proto;
  }

  croak "We can't create a URI from $action with the given arguments: @{[ join ', ', @args ]}]}"
    unless my $uri = $c->uri_for($action, @args);

  return $uri  
}

around 'get_rendered' => sub {
  my ($orig, $self, @args) = @_;
  $self->ctx->stash->{__view_for_code_form} = $self->form->view if $self->has_code;
  $self->ctx->stash->{__view_for_code_pager} = $self->pager->view if $self->has_code;

  local $form->{view} = $self; # Evil Hack lol
  local $form->{context} = $self->ctx;
  local $form->{controller} = $self->ctx->controller;
  local $pager->{view} = $self; # Evil Hack lol
  local $pager->{context} = $self->ctx;
  local $pager->{controller} = $self->ctx->controller;  
  return $self->$orig(@args);
};

around 'execute_code_callback' => sub {
  my ($orig, $self, @args) = @_;
  my $old_view_form = delete $self->ctx->stash->{__view_for_code_form};
  my $old_view_pager = delete $self->ctx->stash->{__view_for_code_pager};

  local $form->{view} = $old_view_form; # Evil Hack lol
  local $form->{context} = $old_view_form->ctx;
  local $form->{controller} = $old_view_form->ctx->controller;
  local $pager->{view} = $old_view_pager; # Evil Hack lol
  local $pager->{context} = $old_view_pager->ctx;
  local $pager->{controller} = $old_view_pager->ctx->controller;  
  return $self->$orig(@args);
};

#around 'prepare_render_args' => sub {
#  my ($orig, $self, @args) = @_;
#  my ($ctx, @orig_args) = $self->$orig(@args);
#  return ($ctx, $self, @orig_args);
#};

__PACKAGE__->config(content_type=>'text/html');
__PACKAGE__->meta->make_immutable;

=head1 NAME

Catalyst::View::Valiant::HTMLBuilder - Per Request, strongly typed Views in code

=head1 SYNOPSIS

    package Example::View::HTML::Home;

    use Moo;
    use Catalyst::View::Valiant::HTMLBuilder
      -tags => qw(div blockquote form_for fieldset),
      -views => 'HTML::Layout', 'HTML::Navbar';

    has info => (is=>'rw', predicate=>'has_info');
    has person => (is=>'ro', required=>1);

    sub render($self, $c) {
      html_layout page_title => 'Sign In', sub($layout) {
        html_navbar active_link=>'/',
        blockquote +{ if=>$self->has_info, 
          class=>"alert alert-primary", 
          role=>"alert" }, $self->info,
        div $self->person->$sf('Welcome {:first_name} {:last_name} to your Example Homepage');
        div {if=>$self->person->profile_incomplete}, [
          blockquote {class=>"alert alert-primary", role=>"alert"}, 'Please complete your profile',
          form_for $self->person, sub($self, $fb, $person) {
            fieldset [
              $fb->legend,
              div +{ class=>'form-group' },
                $fb->model_errors(+{show_message_on_field_errors=>'Please fix validation errors'}),
              div +{ class=>'form-group' }, [
                $fb->label('username'),
                $fb->input('username'),
                $fb->errors_for('username'),
              ],
              div +{ class=>'form-group' }, [
                $fb->label('password'),
                $fb->password('password'),
                $fb->errors_for('password'),
              ],
              div +{ class=>'form-group' }, [
                $fb->label('password_confirmation'),
                $fb->password('password_confirmation'),
                $fb->errors_for('password_confirmation'),
              ],
            ],
            fieldset $fb->submit('Complete Account Setup'),
          ],
        ],
      };
    }

    1;

=head1 DESCRIPTION

B<WARNINGS>: Experimental code that I might need to break back compatibility in order
to fix issues.  

This is a L<Catalyst::View> subclass that provides a way to write views in code
that are strongly typed and per request.  It also integrates with several of L<Valiant>'s
HTML form generation code modules to make it easier to create HTML forms that properly
synchronize with your L<Valiant> models for displaying errors and performing validation.

Unlike most Catalyst views, this view is 'per request' in that it is instantiated for
each request.  This allows you to store per request state in the view object as well as
localize view specific logic to the view object.  In particular it allows you to avoid or
reduce using the stash in order to pass values from the controller to the view.  I think
this can make your views more robust and easier to support for the long term.  It builds
upons L<Catalyst::View::BasePerRequest> which provides the per request behavior so you should
take a look at the documentation and example controller integration in that module in
order to get the idea.

As a quick example here's a possible controller that might invoke the view given in the
SYNOPSIS:

    package Example::Controller::Home;

    use Moose;
    use MooseX::MethodAttributes;

    extends 'Catalyst::Controller';

    sub index($self, $c) {
      my $view = $c->view('HTML::Home', person=>$c->user);
      if( # Some condition ) {
        $view->info('You have been logged in');
      }
    }

    1;

This will then work with the commonly used L<Catalyst::Action::RenderView> or my 
L<Catalyst::ActionRole::RenderView> to produce a view response and set it as the
response body.  

Additionally, this view allows you to import HTML tags from L<Valiant::HTML::Util::TagBuilder>
as well as HTML tag helper methods from L<Valiant::HTML::Util::FormTags> and
L<Valiant::HTML::Util::Form> into your view code.  You should take a look at the
documentation for those modules to see what is available.  Since L<Valiant::HTML::Util::TagBuilder>
includes basic flow control and logic this gives you a bare minimum templating system
that is completely in code.  You can import some utility methods as well as other views
into your view (please see the L</EXPORTS> section below for more details).  This is currently
lightly documented so I recommend also looking at the test cases as well as the example
Catalyst application included in the distribution under the C<example/> directory.

=head1 ATTRIBUTES

This class inherits all of the attributes from L<Catalyst::View::BasePerRequest>

=head1 METHODS

This class inherits all of the methods from L<Catalyst::View::BasePerRequest> as well as:

=head2 form

Returns the current C<form> object.

=head2 tags

A convenience method to get the C<tags> object from the current C<form>.

=head2 safe

Marks a string as safe to render by first escaping it and then wrapping it in a L<Valiant::HTML::SafeString> object.

=head2 raw

Marks a string as safe to render by wrapping it in a L<Valiant::HTML::SafeString> object.

=head2 safe_concat

Given one or more strings and / or L<Valiant::HTML::SafeString> objects, returns
a new L<Valiant::HTML::SafeString> object that is the concatenation of all of the strings.

=head2 escape_html

Given a string, returns a new string that is the escaped version of the original string.

=head2 uri_escape

Given a string, returns a new string that is the URI escaped version of the original string.
Given an array, returns a string that is the URI escaped version of the key value pairs in the array.

=head2 read_attribute_for_html

Given an attribute name, returns the value of that attribute if it exists.  If the attribute does not exist, it will die.

=head2 attribute_exists_for_html

Given an attribute name, returns true if the attribute exists and false if it does notu.

=head2 formbuilder_class 

    sub formbuilder_class { 'Example::FormBuilder' }

Provides an easy way to override the default formbuilder class.  By default it will use
L<Valiant::HTML::FormBuilder>.  You can override this method to return a different class
via a subclass of this view.

=head1 DEFAULT EXPORTS

=over 4

=item user

The current logged in user if any (via C<< $c->user >>)

=item $sf

    $person->$sf('Hi there {:first_name} {:last_name} !!')

Exports a coderef helper that wraps the C<sf> method in L<Valiant::HTML::TagBuilder>.  Useful when
you have an object whos methods you want as values in your view.

=item path

Given an instance of L<Catalyst::Action> or the name of an action, returns the full path to that action
as a url.   Basically a wrapper over C<uri_for> that will die if it can't find the action.  It also
properly support relatively named actions.

=item view

Example

    view 'HTML::Layout', +{ page_title=>'Sign In' }, sub {
      my $layout = shift;
      $layout->div('Hello World');
    };

    view '::Table', {items=>\@items};

Given the name of a view, returns the view object.

If the view name starts with '::' then it will be relative to the current view.  For example if 
the current view is "Example::View::HTML::Home" and the view name is "::Table" then the view object
for "Example::View::HTML::Home::Table" will be returned.  If on the other hand the view name
begins with ".::" then it will look in the same directory as the current view.  For example if 
the current view is "Example::View::HTML::Home" and the view name is ".::Table" then the view object
for "Example::View::HTML::Table" will be returned.

=item content

=item content_for

=item content_append

=item content_replace

=item content_around

Wraps the named methods from L<Catalyst::View::BasePerRequest> for export.  You can still call them
directly on the view object if you prefer.

=item raw

=item safe

=item escape_javascript

=item escape_js

Wraps the named methods from L<Valiant::HTML::SafeString> for export.  You can still call them
directly on the view object if you prefer.

=back

=head1 EXPORTS

=head2 -tags

Export any HTML tag supported in L<Valiant::HTML::TagBuilder> as well as tag helpers from
L<Valiant::HTML::Util::FormTags> and L<Valiant::HTML::Util::Form>.  Please note the C<tr> tag
must be imported by the C<trow> name since C<tr> is a reserved word in Perl.

=head2 -helpers

=head1 SUBCLASSING

You can subclass this view in order to provide your own default behavior and additional methods.

    package View::Example::View;

    use Moo;
    use Catalyst::View::Valiant
      -tags => qw(blockquote label_tag);

    sub formbuilder_class { 'Example::FormBuilder' }

    sub stuff2 {
      my $self = shift;
      $self->label_tag('test', sub {
        my $view = shift;
        die unless ref($view) eq ref($self);
      });
      return $self->tags->div('stuff2');
    }

    sub stuff3 :Renders {
      blockquote 'stuff3', 
      shift->div('stuff333')
    }

    1;

Then the view C<View::Example::View> can be used in exactly the same way as this view.

=head1 TIPS & TRICKS

=head2 Creating render methods

Often you will want to break up your render method into smaller chunks.  You can do this by
creating methods that return L<Valiant::HTML::SafeString> objects.  You can then call these
methods from your render method.  Here's an example:

    sub simple :Renders {
      my $self = shift;
      return div "Hey";
    }

You can then call this method from another render method:

    sub complex :Renders {
      my $self = shift;
      return $self->simple;
    }

Or use it directly in your main render method:

    sub render {
      my $self = shift;
      return $self->simple;
    }

Please note you need to add the ':Renders' attribute to your method in order for it to be
exported as a render method.  You don't need to do that on the main render method in your
class because we handle that for you.

=head2 Calling for view fragments

You can call for the response of any view's method wish is marked as a render method.

  package Example::View::Fragments;

    use Moo;
    use Catalyst::View::Valiant
      -tags => qw(div);

    sub stuff4 :Renders { div 'stuff4' }

    1;

Then in your main view:

  package Example::View::Hello;

    use Moo;
    use Catalyst::View::Valiant
      -views => qw(Fragments);

    sub render {
      my $self = shift;
      return fragment->stuff4;
    }

You can even call them in a controller:

    sub index :Path {
      my ($self, $c) = @_;
      $c->res->body($c->view('Fragments')->stuff4);
    }

=head1 SEE ALSO
 
L<Valiant>, L<Valiant::HTML::Util::Form>, L<Valiant::HTML::Util::FormTags>,
L<Valiant::HTML::Util::Tagbuilder>,  L<Valiant::HTML::SafeString>.

=head1 AUTHOR
 
See L<Valiant>

=head1 COPYRIGHT & LICENSE
 
See L<Valiant>

=cut

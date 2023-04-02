package Catalyst::View::Valiant;

use Moo;
use Sub::Util;
use Valiant::HTML::Util::Form;
use Valiant::HTML::Util::View;
use Valiant::HTML::SafeString ();
use Attribute::Handlers;
use Carp;

extends 'Catalyst::View::BasePerRequest';

my $view = Valiant::HTML::Util::View->new;
my $form = Valiant::HTML::Util::Form->new(view=>$view); # Placeholder, this gets overwritten in the request

## Code Attributes

sub Renders :ATTR(CODE) {
  my ($package, $symbol, $referent, $attr, $data) = @_;
  my $name = *{$symbol}{NAME};
  unless($package->can("__attr_${name}")) {
    my $wrapper = sub {
      my ($self, @args) = @_;
      carp "View method called without correct self" unless $self->isa($package);
      local $form->{view} = $self; # Evil Hack lol
      local $form->{context} = $self->ctx;
      local $form->{controller} = $self->ctx->controller;
      return $referent->(@_);
    };
    Moo::_Utils::_install_tracked($package, "__attr_${name}", $wrapper);
    Moo::_Utils::_install_tracked($package, $name, sub {
      return $package->can("__attr_${name}")->(@_);
    });
  }
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
    } elsif($next eq '-views') {
      $which = 'views';
      next;
    } elsif($next eq '-util') {
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
      push @utils,$next;
    }
  }

  Moo->_set_superclasses($target, $class);

  $class->_install_tags($target, @tags);
  $class->_install_views($target, @views);
  $class->_install_utils($target, @utils);
}

sub form { $form }
sub tags { $form->tags }

sub _install_utils {
  my $class = shift;
  my $target = shift;

  no strict 'refs';
  foreach my $util (@_) {
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
    } elsif($util eq 'path') {
      Moo::_Utils::_install_tracked($target, "__path", $target->can('path'));
      my $sub = sub {
        if(Scalar::Util::blessed($_[0])) {
          return $target->can("__path")->(@_);
        } else {
          return $target->can("__path")->($form->view, @_);
        }
      };
      Moo::_Utils::_install_tracked($target, 'path', $sub);
    }

  }
}

sub _install_tags {
  my $class = shift;
  my $target = shift;
  foreach my $tag (@_) {
    my $method;
    if($form->is_content_tag($tag)) {
      $method = Sub::Util::set_subname "${target}::${tag}" => sub {
        my ($args, $content) = (+{}, '');
        $args = shift if ref $_[0] eq 'HASH';
        if(defined($_[0])) {
          if(Scalar::Util::blessed($_[0]) && $_[0]->isa($class)) {
            $content = shift->get_rendered;
          } else {
            $content = shift;
          }
        }
        return $form->tags->$tag($args, $content), @_;
      };
    } elsif($form->is_void_tag($tag)) {
      $method = Sub::Util::set_subname "${target}::${tag}" => sub {
        my $args = +{};
        $args = shift if ref $_[0] eq 'HASH';
        return $form->tags->$tag($args), @_;
      };
    } elsif($form->can($tag)) {
      $method = Sub::Util::set_subname "${target}::${tag}" => sub {
        ## return $form->safe_concat($form->$tag(@_));
        ## Will ponder this, it seems to be a performance hit
        my @args = ();
        while(@_) {
          last if
            !defined($_[0])
            || (Scalar::Util::blessed($_[0])||'') eq 'Valiant::HTML::SafeString';
          push @args, shift;
        }
        return $form->$tag(@args), @_; 
      };
    } else {
      die "No such tag '$tag' for view";
    }

    Moo::_Utils::_install_tracked($target, $tag, $method);
  }
}

sub _install_views {
  my $class = shift;
  my $target = shift;
  my %view_info = @_;

  foreach my $name (keys %view_info) {
    my $method = Sub::Util::set_subname "${target}::${name}" => sub {
      my (@args) = @_;
      $form->view->ctx->view($view_info{$name}, @args);
    };
    Moo::_Utils::_install_tracked($target, $name, $method);
  }
}

sub safe { shift; return Valiant::HTML::SafeString::safe(@_) }
sub raw { shift; return Valiant::HTML::SafeString::raw(@_) }
sub safe_concat { shift; return Valiant::HTML::SafeString::safe_concat(@_) }
sub escape_html { shift; return Valiant::HTML::SafeString::escape_html(@_) }

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
      
  # Hard error if the spec looks wrong...
  die "$action_proto is not a string" unless ref \$action_proto eq 'SCALAR';
      
  my $action;
  if($action_proto =~/^\/?\*/) {
    die "$action_proto is not a named action"
      unless $action = $c->dispatcher->get_action_by_path($action_proto);
  } elsif($action_proto=~m/^(.*)\:(.+)$/) {
    die "$1 is not a controller"
      unless my $controller = $c->controller($1||'');
    die "$2 is not an action for controller ${\$controller->component_name}"
      unless $action = $controller->action_for($2);
  } elsif($action_proto =~/\//) {
    my $path = $action_proto=~m/^\// ? $action_proto : $c->controller->action_for($action_proto)->private_path;
    die "$action_proto is not a full or relative private action path" unless $path;
    die "$path is not a private path" unless $action = $c->dispatcher->get_action_by_path($path);
  } elsif($action = $c->controller->action_for($action_proto)) {
    # Noop
  } else {
    # Fallback to static
    $action = $action_proto;
  }

  die "We can't create a URI from $action with the given arguments"
    unless my $uri = $c->uri_for($action, @args);

  return $uri  
}

around 'get_rendered' => sub {
  my ($orig, $self, @args) = @_;
  local $form->{view} = $self; # Evil Hack lol
  local $form->{context} = $self->ctx;
  local $form->{controller} = $self->ctx->controller;
  return $self->$orig(@args);
};



__PACKAGE__->config(content_type=>'text/html');

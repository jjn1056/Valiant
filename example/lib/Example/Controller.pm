package Example::Controller;

use Scalar::Util;
use String::CamelCase;
use Moose;

extends 'Catalyst::ControllerPerContext';
with 'Catalyst::ControllerRole::At';

around gather_default_action_roles => sub {
  my ($orig, $self, %args) = @_;
  my @roles = $self->$orig(%args);
  push @roles, 'Catalyst::ActionRole::RequestModel'
    if $args{attributes}->{RequestModel} || 
      $args{attributes}->{QueryModel} || 
      $args{attributes}->{BodyModel} ||
      $args{attributes}->{BodyModelFor}; 
  return @roles;
};

## Future plugin...?
use Scalar::Util;
use Encode 2.21 'decode_utf8';

after 'register_action_methods', sub {
  my ( $self, $app, @methods ) = @_;
  my $class = ref $self;

  my @endpoints = ();
  my @types = @{ $app->dispatcher->dispatch_types ||+[] };
  foreach my $type (@types) {  
    if(ref($type) eq 'Catalyst::DispatchType::Chained') {
      foreach my $endpoint(@{ $type->{_endpoints} || [] }) {
        if ($endpoint->class eq $class) {
          push @endpoints, [$endpoint, $self->_generate_uri_pattern($type, $endpoint)];
        }
      }
    }
  }

  my $avail_width = Catalyst::Utils::term_width() - 9;
  my $col1_width = ($avail_width * .6) < 35 ? 35 : int($avail_width * .6);
  my $col2_width = $avail_width - $col1_width;
  my $paths = Text::SimpleTable->new(
    [ $col1_width, 'uri' ], [ $col2_width, 'helper' ],
  );

  foreach my $endpoint_proto (@endpoints) {
    my $endpoint = $endpoint_proto->[0];
    my $uri = $endpoint_proto->[1];
    my $path_args = '';
    my $path_arg_count = 0;
    if(my @path_args = @{$endpoint_proto->[2]||[]}) {
      $path_arg_count = scalar(@path_args);
      $path_args = join ',', @path_args if scalar(@path_args) > 0;
      $path_args = "([$path_args])";
    }
    my $name = $endpoint->name;
    my $private_path = $endpoint->private_path; $private_path =~s/^\///; $private_path =~s/\//_/g;
    my $sub = sub {
      my $self = shift;
      my ($parts, @args) = $self->_normalize_uri_args(@_);  
      return $self->ctx->uri_for($self->action_for($name), $parts, @args);
    };
    $paths->row($uri, "${name}_uri${path_args}\n${private_path}_uri${path_args}");
    {
      no strict 'refs';
      my $controller_helper = "${class}::${name}_uri";
      *{$controller_helper} = Sub::Util::set_subname $controller_helper => $sub;
      my $app_helper = "${app}::${private_path}_uri";
      my $helper = $endpoint->private_path;
      *{$app_helper} = Sub::Util::set_subname $app_helper => sub {
        my $c = shift;
        return $c->uri_for($c->dispatcher->get_action_by_path($helper), @_);
      };
    }
    
  }

  $app->log->debug("URI Helpers for: $class\n" . $paths->draw . "\n");
};

sub _generate_uri_pattern {
  my ($self, $dispatcher, $endpoint) = @_;
  my $args = $endpoint->list_extra_info->{Args};

  my @parts;
  if($endpoint->has_args_constraints) {
      @parts = map { "{$_}" } $endpoint->all_args_constraints;
  } elsif(defined $endpoint->attributes->{Args}) {
      @parts = (defined($endpoint->attributes->{Args}[0]) ? (("*") x $args) : '...');
  }

  my @parents = ();
  my $parent = "DUMMY";
  my $extra  = $dispatcher->_list_extra_http_methods($endpoint);
  my $consumes = $dispatcher->_list_extra_consumes($endpoint);
  my $scheme = $dispatcher->_list_extra_scheme($endpoint);
  my $curr = $endpoint;
  while ($curr) {
      if (my $cap = $curr->list_extra_info->{CaptureArgs}) {
          if($curr->has_captures_constraints) {
              my $names = join '/', map { "{$_}" } $curr->all_captures_constraints;
              unshift(@parts, $names);
          } else {
              unshift(@parts, (("*") x $cap));
          }
      }
      if (my $pp = $curr->attributes->{PathPart}) {
          unshift(@parts, $pp->[0])
              if (defined $pp->[0] && length $pp->[0]);
      }
      $parent = $curr->attributes->{Chained}->[0];
      $curr = $dispatcher->_actions->{$parent};
      unshift(@parents, $curr) if $curr;
  }
  my @path_args = ();
  foreach my $p (@parents) {
      my $name = "/${p}";

      if (defined(my $extra = $dispatcher->_list_extra_http_methods($p))) {
          $name = "${extra} ${name}";
      }
      if (defined(my $cap = $p->list_extra_info->{CaptureArgs})) {
          if($p->has_captures_constraints) {
            my $tc = join ',', @{$p->captures_constraints};
            $name .= " ($tc)";
            push @path_args, $tc if $tc;
          } else {
            $name .= " ($cap)";
            push @path_args, $cap if $cap;
          }
      }
      if (defined(my $ct = $p->list_extra_info->{Consumes})) {
          $name .= ' :'.$ct;
      }
      if (defined(my $s = $p->list_extra_info->{Scheme})) {
          $scheme = uc $s;
      }
  }

  my @display_parts = map { $_ =~s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg; decode_utf8 $_ } @parts;
  my $path = join('/', '', @display_parts) || '/';
  $path = "${extra} ${path}" if $extra;

  return $path, \@path_args;
}

sub _normalize_uri_args {
  my $self = shift;
  my $parts_proto = shift if $_[0] && ((ref($_[0]) eq 'ARRAY') || ( blessed($_[0]) ));
  my $query = shift if $_[0] && (ref($_[0]) eq 'HASH');
  my $fragment = shift if $_[0] && (ref($_[0]) eq 'SCALAR');

  my $c = $self->ctx;
  my @parts = ();

  # If parts are passed in then use them. If just one and its a blessed object
  # then use its id. If an arrayref then use the ids of the objects.
  if(blessed $parts_proto) {
    push @parts, $parts_proto->id;
  } elsif(ref($parts_proto) eq 'ARRAY') {
    my @part_ids = map { blessed $_ ? $_->id : $_ } @$parts_proto;
    push @parts, @part_ids;
  }

  my @return_args = (\@parts);
  push @return_args, $query if $query;
  push @return_args, $fragment if $fragment;

  return @return_args;
}

## This stuff will go into a role sooner or later

sub view {
  my ($self, @args) = @_;
  return $self->ctx->stash->{current_view_instance} if exists($self->ctx->stash->{current_view_instance}) && !@args;
  return $self->view_for($self->ctx->action, @args);
}

sub view_for {
  my ($self, $action_proto, @args) = @_;
  my $action = Scalar::Util::blessed($action_proto) ?
    $action_proto :
      $self->action_for($action_proto);

  return die "No action for $action_proto" unless $action;

  my $action_namepart = $self->_action_namepart_from_action($action);
  my $view = $self->_build_view_name($action_namepart);

  $self->ctx->log->debug("Initializing View: $view") if $self->ctx->debug;
  return $self->ctx->view($view, @args);
}

sub _action_namepart_from_action {
  my ($self, $action) = @_;
  my $action_namepart = String::CamelCase::camelize($action->reverse);
  $action_namepart =~s/\//::/g;
  return $action_namepart;
}

sub _build_view_name {
  my ($self, $action_namepart) = @_;

  my $accept = $self->ctx->request->headers->header('Accept');
  my $available_content_types = $self->_content_negotiation->{content_types};
  my $content_type = $self->_content_negotiation->{negotiator}->choose_media_type($available_content_types, $accept);
  my $matched_content_type = $self->_content_negotiation->{content_types_to_prefixes}->{$content_type};

  $self->ctx->log->warn("no matching type for $accept") unless $matched_content_type;
  $self->ctx->detach_error(406, +{error=>"Requested not acceptable."}) unless $matched_content_type;
  $self->ctx->log->debug( "Content-Type: $content_type, Matched: $matched_content_type") if $self->ctx->debug;

  my $view = $self->_view_from_parts($matched_content_type, $action_namepart);
  return $view;
}

sub _view_from_parts {
  my ($self, @view_parts) = @_;
  my $view = join('::', @view_parts);
  $self->ctx->log->debug("Negotiated View: $view") if $self->ctx->debug;
  return $view;
}

has '_content_negotiation' => (is => 'ro', required=>1);

sub process_component_args {
  my ($class, $app, $args) = @_;

  my $n = HTTP::Headers::ActionPack->new->get_content_negotiator;
  my %content_prefixes = %{ delete($args->{content_prefixes}) || +{} };
  my @content_types = map { @$_ } values %content_prefixes;
  my %content_types_to_prefixes = map {
    my $prefix = $_; 
    map {
      $_ => $prefix
    } @{$content_prefixes{$prefix}}
  } keys %content_prefixes;

  return +{
    %$args,
    _content_negotiation => +{
      content_prefixes => \%content_prefixes,
      content_types_to_prefixes => \%content_types_to_prefixes,
      content_types => \@content_types,
      negotiator => $n,
    },
  };
}

our %content_prefixes = (
  'HTML' => ['application/xhtml+xml', 'text/html'],
  'JSON' => ['application/json'],
  'XML' => ['application/xml', 'text/xml'],
  'JS' => ['application/javascript', 'text/javascript'],
);

__PACKAGE__->config(
  content_prefixes => \%content_prefixes,
);

__PACKAGE__->meta->make_immutable;
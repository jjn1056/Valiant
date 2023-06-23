package Example::Controller;

use Scalar::Util;
use String::CamelCase;
use Moose;

extends 'Catalyst::ControllerPerContext';
with 'Catalyst::ControllerRole::At';

around gather_default_action_roles => sub {
  my ($orig, $self, %args) = @_;
  my @roles = $self->$orig(%args);
  push @roles, 'Catalyst::ActionRole::CurrentView'
    if $args{attributes}->{View};
  push @roles, 'Catalyst::ActionRole::RequestModel'
    if $args{attributes}->{RequestModel} || 
      $args{attributes}->{QueryModel} || 
      $args{attributes}->{BodyModel} ||
      $args{attributes}->{BodyModelFor}; 
  return @roles;
};


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



our %content_types_to_prefixes = map {
  my $prefix = $_; 
  map {
    $_ => $prefix
  } @{$prefixes{$prefix}}
} keys %prefixes;

our @content_types = map { @$_ } values %prefixes;

our $n = HTTP::Headers::ActionPack->new->get_content_negotiator;

sub _build_view_name {
  my ($self, $action_namepart) = @_;
  my @view_parts = ($action_namepart);


  my %views = map { $_ => 1 } $self->ctx->views;

  my $accept = $self->ctx->request->headers->header('Accept');
  my $content_type = $n->choose_media_type(\@content_types, $accept);
  my $matched_content_type = $content_types_to_prefixes{$content_type};

  $self->ctx->log->warn("no matching type for $accept") unless $matched_content_type;
  $self->ctx->detach_error(406, +{error=>"Requested not acceptable."}) unless $matched_content_type;

  warn "Content-Type: $content_type, Matched: $matched_content_type";
  unshift @view_parts, $matched_content_type;

  my $view = join('::', @view_parts);

  return $view;
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
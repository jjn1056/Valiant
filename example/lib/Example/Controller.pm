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

has view_prefix_namespace => (
  init_arg=>'view_prefix_namespace',
  is=>'rw', 
  required=>1, 
  lazy=>1, 
  builder=>'_build_view_prefix_namespace',
);

  sub _build_view_prefix_namespace { return '' }

  sub get_view_prefix_namespace { return shift->view_prefix_namespace }

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
  my $view = "@{[ $self->get_view_prefix_namespace ]}::@{[ $action_namepart ]}";
  return $view;
}

__PACKAGE__->meta->make_immutable;
__PACKAGE__->config(view_prefix_namespace=>'HTML');

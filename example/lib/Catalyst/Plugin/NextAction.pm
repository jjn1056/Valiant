package Catalyst::Plugin::NextAction;

use warnings;
use strict;

use Catalyst::ActionChain;
use Catalyst::Action;

sub next_action {  return $_[0]->action->next(@_) }

package Catalyst::ActionChain;

use warnings;
use strict;
no warnings 'redefine';

sub dispatch {
    my ( $self, $c ) = @_;
    my @captures = @{$c->req->captures||[]};
    my @chain = @{ $self->chain };
    my $last = pop(@chain);
    $c->stash(_action_chain_actions => \@chain);
    $c->stash(_action_chain_last_action => $last);
    $c->stash(_action_chain_captures => \@captures);
    $c->stash(_action_chain_original_args => $c->request->{arguments});
    $self->_dispatch_chain_actions($c);
}

sub next {
    my ($self, $c, @args) = @_;

    if(exists $c->stash->{_action_chain_last_action}) {
      $c->stash->{_action_chain_next_args} = @args ? \@args : [];
      $self->_dispatch_chain_actions($c);
    } else {
      $c->action->chain->[-1]->next($c, @args) if $c->action->chain->[-1]->can('next');
    }

    return @{ delete $c->stash->{_action_chain_action_return} } if exists $c->stash->{_action_chain_action_return};
}

sub _dispatch_chain_actions {
    my ($self, $c) = @_;
    while( @{ $c->stash->{_action_chain_actions}||[] } ) {
        $self->_dispatch_chain_action($c);
        return if $self->_abort_needed($c);        
    }
    if(exists($c->stash->{_action_chain_last_action})) {
      $c->request->{arguments} = delete $c->stash->{_action_chain_original_args};
      unshift @{$c->request->{arguments}}, @{delete $c->stash->{_action_chain_next_args}} if exists $c->stash->{_action_chain_next_args};
      my $last_action = delete $c->stash->{_action_chain_last_action};
      $last_action->dispatch($c);
    }
}

sub _dispatch_chain_action {
    my ($self, $c) = @_;
    my $action = shift(@{ $c->stash->{_action_chain_actions}||[] });
    my @args;
    if (my $cap = $action->number_of_captures) {
        @args = splice(@{ $c->stash->{_action_chain_captures}||[] }, 0, $cap);
    }
    unshift @args, @{delete $c->stash->{_action_chain_next_args}} if exists $c->stash->{_action_chain_next_args};
    local $c->request->{arguments} = \@args;
    $action->dispatch( $c );
}

sub _abort_needed {
    my ($self, $c) = @_;
    my $abort = defined($c->config->{abort_chain_on_error_fix}) ? $c->config->{abort_chain_on_error_fix} : 1;
    return 1 if ($c->has_errors && $abort); 
}

package Catalyst::Action;

use warnings;
use strict;
no warnings 'redefine';

sub execute {
  my ($self, $controller, $ctx, @args) = @_;
  my @ret = $self->code->($controller, $ctx, @args);

  $ctx->stash(_action_chain_action_return => \@ret);
  return @ret;
}

1;

package Catalyst::Plugin::NextAction;

use Moose::Role;
use Catalyst::ActionChain;

has _last_action_state => (is => 'rw', predicate=>'has_last_action_state');

sub last_action_state {
  my ($c) = @_;
  return $c->has_last_action_state ? @{ $c->_last_action_state() } : ();
}

sub execute {
    my ( $c, $class, $code ) = @_;
    $class = $c->component($class) || $class;
 
    my $stats_info = $c->_stats_start_execute( $code ) if $c->use_stats;
 
    push( @{ $c->stack }, $code );
 
    no warnings 'recursion';
    # N.B. This used to be combined, but I have seen $c get clobbered if so, and
    #      I have no idea how, ergo $ret (which appears to fix the issue)
    eval {
      my @ret = $code->execute($class, $c, @{ $c->req->args }); 
      my $ret = scalar(@ret) > 1 ? @ret : $ret[0]||0;
      $c->_last_action_state(\@ret);
      $c->state($ret);
    };
 
    $c->_stats_finish_execute( $stats_info ) if $c->use_stats and $stats_info;
 
    my $last = pop( @{ $c->stack } );
 
    if ( my $error = $@ ) {
        #rethow if this can be handled by middleware
        if ( $c->_handle_http_exception($error) ) {
            foreach my $err (@{$c->error}) {
                $c->log->error($err);
            }
            $c->clear_errors;
            $c->log->_flush if $c->log->can('_flush');
 
            $error->can('rethrow') ? $error->rethrow : croak $error;
        }
        if ( blessed($error) and $error->isa('Catalyst::Exception::Detach') ) {
            $error->rethrow if $c->depth > 1;
        }
        elsif ( blessed($error) and $error->isa('Catalyst::Exception::Go') ) {
            $error->rethrow if $c->depth > 0;
        }
        else {
            unless ( ref $error ) {
                no warnings 'uninitialized';
                chomp $error;
                my $class = $last->class;
                my $name  = $last->name;
                $error = qq/Caught exception in $class->$name "$error"/;
            }
            $c->error($error);
        }
    }
    return $c->state;
}

package Catalyst::ActionChain;

use Moose;
__PACKAGE__->meta->make_mutable;
has _current_chain_actions => (is=>'rw', init_arg=>undef, predicate=>'_has_current_chain_actions');
has _chain_last_action => (is=>'rw', init_arg=>undef, predicate=>'_has_chain_last_action', clearer=>'_clear_chain_last_action');
has _chain_captures => (is=>'rw', init_arg=>undef);
has _chain_original_args => (is=>'rw', init_arg=>undef, clearer=>'_clear_chain_original_args');
has _chain_next_args => (is=>'rw', init_arg=>undef, predicate=>'_has_chain_next_args', clearer=>'_clear_chain_next_args');
has _context => (is => 'rw', weak_ref => 1);

no warnings 'redefine';
no Moose;

sub dispatch {
    my ( $self, $c ) = @_;
    my @captures = @{$c->req->captures||[]};
    my @chain = @{ $self->chain };
    my $last = pop(@chain);

    $self->_current_chain_actions(\@chain);
    $self->_chain_last_action($last);
    $self->_chain_captures(\@captures);
    $self->_chain_original_args($c->request->{arguments});
    $self->_context($c);
    $self->_dispatch_chain_actions($c);
}

sub next {
    my ($self, @args) = @_;
    my $ctx = $self->_context;

    if($self->_has_chain_last_action) {
        @args ? $self->_chain_next_args(\@args) : $self->_chain_next_args([]);
        $self->_dispatch_chain_actions($ctx);
    } else {
        $ctx->action->chain->[-1]->next($ctx, @args) if $ctx->action->chain->[-1]->can('next');
    }

    return $ctx->last_action_state if $ctx->has_last_action_state;
}

sub _dispatch_chain_actions {
    my ($self, $c) = @_;
    while( @{$self->_current_chain_actions||[]}) {
        $self->_dispatch_chain_action($c);
        return if $self->_abort_needed($c);        
    }
    if($self->_has_chain_last_action) {
        $c->request->{arguments} = $self->_chain_original_args;
        $self->_clear_chain_original_args;
        unshift @{$c->request->{arguments}}, @{ $self->_chain_next_args} if $self->_has_chain_next_args;
        $self->_clear_chain_next_args;
        my $last_action = $self->_chain_last_action;
        $self->_clear_chain_last_action;
        $last_action->dispatch($c);
    }
}

sub _dispatch_chain_action {
    my ($self, $c) = @_;
    my ($action, @remaining_actions) = @{ $self->_current_chain_actions||[] };
    $self->_current_chain_actions(\@remaining_actions);
    my @args;
    if (my $cap = $action->number_of_captures) {
        @args = splice(@{ $self->_chain_captures||[] }, 0, $cap);
    }
    unshift @args, @{ $self->_chain_next_args} if $self->_has_chain_next_args;
    $self->_clear_chain_next_args;
    local $c->request->{arguments} = \@args;
    $action->dispatch( $c );
}

sub _abort_needed {
    my ($self, $c) = @_;
    my $abort = defined($c->config->{abort_chain_on_error_fix}) ? $c->config->{abort_chain_on_error_fix} : 1;
    return 1 if ($c->has_errors && $abort); 
}

1;

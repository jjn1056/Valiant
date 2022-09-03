package Example::ActionRole::Authenticated;

use Moose::Role;

requires 'match', 'match_captures';

around ['match','match_captures'] => sub {
  my ($orig, $self, $ctx, @args) = @_; 
  return $ctx->can('user') && $ctx->user->authenticated ? $self->$orig($ctx, @args) : 0;
};

1;

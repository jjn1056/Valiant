package Valiant::Params::Role;

use Moo::Role;
use Scalar::Util 'blessed';
use Valiant::Util 'throw_exception', 'debug';
use namespace::autoclean -also => ['throw_exception', 'debug'];

requires 'ancestors';

sub _to_class {
  my $proto = shift;
  return ref($proto) ? ref($proto) : $proto;
}

my $_params = +{};

sub __add_param {
  my ($class, $attr) = (shift, shift);
  my $varname = "${class}::_params";
  my %options = (
    name => $attr,
    multi => 0,
  @_);

  no strict "refs";
  $$varname->{$attr} = \%options;
  return %{ $$varname };
}

sub params_info {
  my $class = _to_class(shift);
  my $varname = "${class}::_params";

  no strict "refs";
  return %{ $$varname },
    map { $_->params_info }
    grep { $_ && $_->can('params_info') }
      $class->ancestors;
}

sub param {
  my $class = _to_class(shift);
  if(ref $_[0] eq 'ARRAY') {
    my @params = @{$_[0]};
    $class->__add_param($_) for @params;
  } else {
    $class->__add_param(@_);
  }
}

sub _normalize_param_value {
  my ($class, $param_info, $value) = @_;
  if($param_info->{multi}) {
    $value = ref($value)||'' eq 'ARRAY' ? $value : [$value];
  } else {
    $value = ref($value)||'' eq 'ARRAY' ? $value->[-1] : $value;
  }
  return $value;
}

sub _params_from_HASH {
  my ($class, %req) = @_;
  my %args_from_request = ();
  my %params_info = $class->params_info;
  foreach my $param (keys %params_info) {
    next unless exists $req{ $params_info{$param}{name} };
    my $value = $class->_normalize_param_value($params_info{$param}, $req{$params_info{$param}{name}});
    $args_from_request{$params_info{$param}{name}} = $value;
  }
  return %args_from_request;
}

sub _params_from_Catalyst_Request {
  my ($class, $req) = @_;
  my %args_from_request = ();
  my %params_info = $class->params_info;
  foreach my $param (keys %params_info) {
    next unless exists $req->body_parameters->{ $params_info{$param}{name} };
    my $value = $class->_normalize_param_value($params_info{$param}, $req->body_parameters->{ $params_info{$param}{name} });
    $args_from_request{$params_info{$param}{name}} = $value;
  }
}

sub _params_from_Plack_Request {
  my ($class, $req) = @_;
  my %args_from_request = ();
  my %params_info = $class->params_info;
  foreach my $param (keys %params_info) {
    next unless exists $req->body_parameters->{ $params_info{$param}{name} };
    my $value = $class->_normalize_param_value($params_info{$param}, $req->body_parameters->{ $params_info{$param}{name} });
    $args_from_request{$params_info{$param}{name}} = $value;
  }
}

  #query

  # param_keys          key (attribute) names that are marked as params
  # params_flattened    array when the pairs are flattened out like incoming from form POST
  # params_as_hashref   
  # get_param
  # param_exists
  # params_each
  # params_map


around BUILDARGS => sub {
  my ( $orig, $class, @args ) = @_;
  my $attrs = $class->$orig(@args);
  my %params = ();
  if(my $request_proto = delete($attrs->{request})) {
    if(ref($request_proto)||'' eq 'HASH') {
      %params = $class->_params_from_HASH(%$request_proto);
    } elsif(my $request_class = blessed($request_proto)) {
      $request_class =~s/::/_/g;
      my $from_method = "_params_from_${request_class}";
      if($class->can($from_method)) {
        %params = $class->$from_method($request_proto);
      }
    } else {
      die "Can't find params in $request_proto";
    }
  }
  return +{
    %params,
    %$attrs,
  };
};

1;

=head1 NAME

Valiant::Params::Role - Role to add HTTP POST Body Request mapping 

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CLASS METHODS

=head1 AUTHOR
 
John Napiorkowski L<email:jjnapiork@cpan.org>
  
=head1 SEE ALSO
 
L<Valiant>

=head1 COPYRIGHT & LICENSE
 
Copyright 2020, John Napiorkowski L<email:jjnapiork@cpan.org>
 
This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut


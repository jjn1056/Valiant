package CatalystX::RequestModel::ContentBodyParser;

{
  package CatalystX::RequestModel::Utils::ContentBodyParser::InvalidJSON;
   
  use Moose;
  with 'CatalystX::Utils::DoesHttpException';
   
  has 'param' => (is=>'ro', required=>1);
  has 'parsing_error' => (is=>'ro', required=>1);

  sub status_code { 400 }
  sub error { "JSON decode error for parameter '@{[ $_[0]->param]}': @{[ $_[0]->parsing_error]}" }

  __PACKAGE__->meta->make_immutable;
}

use warnings;
use strict;
use Module::Runtime ();
use CatalystX::RequestModel::Utils::ContentBodyParser::InvalidJSON;

sub content_type { die "Must be overridden" }

sub parse { die "Must be overridden"}

sub normalize_value {
  my ($self, $param, $value, $key_rules) = @_;

  if($key_rules->{always_array}) {
    $value = [$value] unless (ref($value)||'') eq 'ARRAY';
  } elsif($key_rules->{flatten}) {
    $value = $value->[-1] if (ref($value)||'') eq 'ARRAY';
  }

  if( ($key_rules->{expand}||'') eq 'JSON' ) {
    eval {
      $value = $self->json_parser($value);
    } || do {
      CatalystX::RequestModel::Utils::ContentBodyParser::InvalidJSON->throw(param=>$self->param, parsing_error=>$@);
    };
  }

  $value = $self->normalize_boolean($value) if ($key_rules->{boolean}||'');

  return $value;
}

sub normalize_boolean {
  my ($self, $value) = @_;
  return $value ? 1:0
}

my $_JSON_PARSER;

sub _build_json_parser {
  return my $parser = Module::Runtime::use_module('JSON::MaybeXS')->new(utf8 => 1);
}

sub json_parse {
  my ($self, $string) = @_;
  $_JSON_PARSER ||= $self->_build_json_parser;
  return $_JSON_PARSER->decode($string); # TODO need to catch errors
}

1;

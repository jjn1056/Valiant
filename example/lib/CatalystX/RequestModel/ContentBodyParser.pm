package CatalystX::RequestModel::ContentBodyParser;

use warnings;
use strict;
use Module::Runtime ();

sub content_type { die "Must be overridden" }

sub parse { die "Must be overridden"}

sub normalize_value {
  my ($self, $value, $key_rules) = @_;
  if($key_rules->{always_array}) {
    $value = [$value] unless (ref($value)||'') eq 'ARRAY';
  } elsif($key_rules->{flatten}) {
    $value = $value->[-1] if (ref($value)||'') eq 'ARRAY';
  }
  $value = $self->json_parser($value) if ($key_rules->{expand}||'') eq 'JSON';
  return $value;
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

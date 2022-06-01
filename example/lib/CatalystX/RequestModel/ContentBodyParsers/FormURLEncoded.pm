package CatalystX::RequestModel::ContentBodyParsers::FormURLEncoded;

use warnings;
use strict;
use Module::Runtime ();

sub content_type { 'application/x-www-form-urlencoded' }

sub parse {
  my ($class, $c, $ns, $rules) = @_;
  my $body_parameters = $c->req->body_parameters;
  return %{ $class->handle_form_encoded($body_parameters, $ns, $rules) };
}

sub handle_form_encoded {
  my ($class, $body_parameters, $ns, $rules) = @_;

  my $current = +{};
  while(@$rules) {
    my $current_rule = shift @{$rules};
    my ($attr, $attr_rules) = %$current_rule;
    my $param_name = $attr_rules->{name};

    $attr_rules = +{ flatten=>1, %$attr_rules }; ## Set defaults

    # TODO handle $rule->{indexed}

    if($attr_rules->{model}) {
      # need to dive into the related model
    } else {
      my $body_parameter_name = join '.', @$ns, $param_name;
      die "400 Bad Request $body_parameter_name   '$param_name'" unless exists $body_parameters->{$body_parameter_name};   ## TODO needs to be a proper Bad Request Exception class
      my $value = $body_parameters->{$body_parameter_name};
      $current->{$attr} = $class->normalize_value($value, $attr_rules);
    }
  }
  return $current;
}

sub normalize_value {
  my ($class, $value, $key_rules) = @_;
  if($key_rules->{always_array}) {
    $value = [$value] unless (ref($value)||'') eq 'ARRAY';
  } elsif($key_rules->{flatten}) {
    $value = $value->[-1] if (ref($value)||'') eq 'ARRAY';
  }
  $value = $class->json_parser($value) if ($key_rules->{expand}||'') eq 'JSON';
  return $value;
}

my $_JSON_PARSER;

sub _build_json_parser {
  return my $parser = Module::Runtime::use_module('JSON::MaybeXS')->new(utf8 => 1);
}

sub json_parse {
  my ($class, $string) = @_;
  $_JSON_PARSER ||= $class->_build_json_parser;
  return $_JSON_PARSER->decode($string); # TODO need to catch errors
}

1;

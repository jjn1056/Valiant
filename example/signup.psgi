#!/usr/local/env plackup

use strict;
use warnings;

use Plack::Request;
use SignUp;
use Pages;

my $pages = Pages->new;

sub post {
  my $req = shift;
  my %params = %{$req->body_parameters}{qw/
    username 
    password 
    password_confirmation
  /};

  (my $signup = SignUp->new(%params))
    ->validate;

  return $signup;
}

my $app = sub {
  my $req = Plack::Request->new(my $env = shift);
  my $signup = $req->method eq 'POST' ? post($req) : SignUp->new;
  my $body = $pages->signup(model => $signup);

  return [ 200,
    [ 'Content-Type'=>'text/html' ],
    [ $body ],
  ];
};

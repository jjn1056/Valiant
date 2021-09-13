use Test::Most;
use Test::Lib;

{
  package MooRole;

  use Moo::Role;

  sub test { return \@_; }

  BEGIN {
    # For exporter
    *test_for_exporter = \&test;
  }  
  
  use Moo::_Utils;
  Moo::_Utils::_install_tracked(__PACKAGE__, 'test', \&test_target);
  
  package Base;
  use Moo;
  use OP::Issue::Importer;

  Test::Most::is_deeply test(1), ["Base", 1];

  package Person;
  use Moo;
  use OP::Issue::Importer;

  extends 'Base';

  Test::Most::is_deeply test(2), ["Person", 2];
}

{
  use v5.26;
  use Object::Pad;

  class OP::Base  {
    use OP::Issue::Importer;
    Test::Most::is_deeply test(1), ["OP::Base", 1];
  }

  class OP::Person isa OP::Base {
    use OP::Issue::Importer;
    Test::Most::is_deeply test(2), ["OP::Person", 2];  # is getting ["OP::Base", "OP::Person", 2]
  }
}

{
  package Retiree;

  use Moo;
  with 'MooRole';
}

is_deeply(Retiree->test(3), ['Retiree', 3]);

done_testing;

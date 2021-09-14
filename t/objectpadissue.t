use Test::Most;
use Test::Lib;

# Moo Tests

{
  package MooRole;

    use Moo::Role;

    sub test { return \@_; }
  
  package Base;

    use Moo;
    use OP::Issue::Importer;

    Test::Most::is_deeply test(1), ["Base", 1], 'got correct base class name and args';

  package Person;

    use Moo;
    use OP::Issue::Importer;

    extends 'Base';

    Test::Most::is_deeply test(2), ["Person", 2], 'got correct subclass name and args';

  package Retiree;

    use Moo;
    with 'MooRole';

    Test::Most::is_deeply(Retiree->test(3), ['Retiree', 3], 'Still works as a role');
}

# Object::Pad tests

{
  use v5.26;
  use Object::Pad;

  class OP::Base  {
    use OP::Issue::Importer;
    Test::Most::is_deeply test(4), ["OP::Base", 4], 'Works with Object::Pad base class';
  }

  class OP::Person isa OP::Base {
    use OP::Issue::Importer;
    Test::Most::is_deeply test(5), ["OP::Person", 5], 'Works with Object::Pad subclass';
  }
}

done_testing;

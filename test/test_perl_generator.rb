require "test/unit"
require "sapphire/perl_generator"

class TestPerlGenerator < Test::Unit::TestCase
  def setup
    @generator = Sapphire::PerlGenerator.new nil, nil
  end

  def assert_code(expected, actual)
    assert_equal expected.gsub(/^ +/, ''), @generator.generate(actual)
  end

  def test_initialize
    generator = Sapphire::PerlGenerator.new
    assert_equal <<-EXPECTED.gsub(/^ +/, '').strip, generator.generate('1 + 1')
      use strict;
      use warnings;
      1 + 1;
      1;
    EXPECTED

    generator = Sapphire::PerlGenerator.new "use My::Util;\n", "\nOK;"
    assert_equal <<-EXPECTED.gsub(/^ +/, '').strip, generator.generate('1 + 1')
      use My::Util;
      1 + 1;
      OK;
    EXPECTED

    generator = Sapphire::PerlGenerator.new nil, nil
    assert_equal <<-EXPECTED.gsub(/^ +/, '').strip, generator.generate('1 + 1')
      1 + 1;
    EXPECTED
  end

  def test_generate_general
    assert_code '1 + 1;', '1 + 1'
    assert_code 'method_call("abc");', 'method_call "abc"'
    assert_code 'inner(outer("abc"));', 'inner outer("abc")'
    assert_code 'my $var = 1;', 'var = 1'
    assert_code 'my @ary = (1, 2, 3);', 'ary = [1, 2, 3]'
    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my @ary = (1, 2, 3);
      $ary[1];
    EXPECTED
      ary = [1, 2, 3]
      ary[1]
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my $ary = [(1, 2, 3)];
      $ary->[1];
    EXPECTED
      ary = [1, 2, 3].to_arrayref
      ary[1]
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my $var = "foo";
      $var = "bar";
    EXPECTED
      var = 'foo'
      var = 'bar'
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my $workbook = undef;
      $workbook->[1]->{"A3"};
    EXPECTED
      workbook = nil
      workbook[1]['A3']
    ACTUAL

    assert_code '$ENV{"KEY"};', 'ENV["KEY"]'
    assert_code '$SIG{"KEY"};', 'SIG["KEY"]'
    assert_code 'no strict "refs";', 'no strict "refs"'

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my $func = sub {
        my $arg = shift;

      }
      ;
      $func->($arg);
    EXPECTED
      func = ->(arg){}
      func.__call__(arg)
    ACTUAL

    assert_code 'my @ary = @_;', 'ary = @_'
    assert_code 'module::method(1);', 'module__method 1'
    assert_code '\&foo;', 'method(:foo)'
  end

  def test_generate_eq
    assert_code 'var() eq "str";', 'var == "str"'
    assert_code '"str" eq var();', '"str" == var'
    assert_code 'var() == 1;', 'var == 1'
    assert_code '1 == var();', '1 == var'
  end

  def test_generate_assign
    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my @ary = ();
      my @var = map {
        do_something();
      } @ary;
    EXPECTED
      ary = []
      var = ary.map do
        do_something
      end
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my $ary = undef;
      my @var = map {
        do_something();
      } @{$ary};
    EXPECTED
      ary = nil
      var = ary.map do
        do_something
      end
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my @ary1 = ();
      my @ary2 = @ary1;
    EXPECTED
      ary1 = []
      ary2 = ary1
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my @ary1 = ();
      my $ary2 = [@ary1];
    EXPECTED
      ary1 = []
      ary2 = ary1.to_arrayref
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my @ary1 = ();
      my $ary2 = scalar(@ary1);
    EXPECTED
      ary1 = []
      ary2 = scalar ary1
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my @ary = ();
      $ary[0] ||= {};
    EXPECTED
      ary = []
      ary[0] ||= {}
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my $ary = {};
      $ary->{0} ||= {};
    EXPECTED
      ary = {}
      ary[0] ||= {}
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my $val = undef;
      $val ||= {};
    EXPECTED
      val = nil
      val ||= {}
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my $val1 = undef;
      my *val2 = $val1;
    EXPECTED
      val1 = nil
      val2 = val1.to_glob
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      local $val1 = 1;
    EXPECTED
      local do val1 = 1; end
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      local $val1 = 1;
      local $val2 = 2;
    EXPECTED
      local do
        val1 = 1
        val2 = 2
      end
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      local $SIG{"key"} = 1;
    EXPECTED
      local do SIG['key'] = 1; end
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      "string" = 1;
    EXPECTED
      __lvar__["string"] = 1
    ACTUAL
  end

  def test_generate_define_and_assign
    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my $val = 1;
      $val = 2;
    EXPECTED
      val = 1
      val = 2
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      our $val = 1;
      $val = 2;
    EXPECTED
      @@val = 1
      @@val = 2
    ACTUAL
  end

  def test_generate_dstr
    assert_code '"Hello, " . world() . "!"', '"Hello, #{world}!"'
    assert_code '"" . hello() . ", world!"', '"#{hello}, world!"'
    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my $world = "world";
      "Hello, " . $world . "!"
    EXPECTED
      world = 'world'
      "Hello, \#{world}!"
    ACTUAL
  end

  def test_generate_replace
    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my $str = "abcabc";
      $str =~ s/b/B/;
    EXPECTED
      str = 'abcabc'
      str.gsub! /b/, 'B'
    ACTUAL
  end

  def test_generate_if
    assert_code <<-EXPECTED.strip, <<-ACTUAL
      bool() ? do_something() : do_other();
    EXPECTED
      if bool
        do_something
      else
        do_other
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      if (bool()) {
        my $var = 1
      }
      else {
        do_other()
      }
    EXPECTED
      if bool
        var = 1
      else
        do_other
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      if (bool()) {
        do_something()
      }
      elsif (bool2()) {
        do_anotherthing()
      }
      else {
        do_other()
      }
    EXPECTED
      if bool
        do_something
      elsif bool2
        do_anotherthing
      else
        do_other
      end
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      bool() ? do_something() : do_other();
    EXPECTED
      bool ? do_something : do_other
    ACTUAL

    # TODO
    assert_code <<-EXPECTED, <<-ACTUAL
      if (bool()) {
        do_something()
      }
    EXPECTED
      do_something if bool
    ACTUAL
  end

  def test_generate_unless
    assert_code <<-EXPECTED, <<-ACTUAL
      unless (bool()) {
        do_something()
      }
    EXPECTED
      do_something unless bool
    ACTUAL
  end

  def test_generate_exception
    assert_code <<-EXPECTED, <<-ACTUAL
      eval {
        1 / 0
      };
      if ($@) {
        recover();
      }

    EXPECTED
      begin
        1 / 0
      rescue
        recover
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      eval {
        do_something();
        1 / 0;
      };
      if ($@) {
        recover();
        recover_more();
      }

    EXPECTED
      begin
        do_something
        1 / 0
      rescue
        recover
        recover_more
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      eval {
        1 / 0
      };
      if ($@) {
        my $e = $@;
        print($e . "\\n");
      }

    EXPECTED
      begin
        1 / 0
      rescue => e
        puts e
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      eval {
        1 / 0
      };
      if ($@ && $@->isa("ZeroDivisionError")) {
        print("error" . "\\n");
      }

    EXPECTED
      begin
        1 / 0
      rescue ZeroDivisionError
        puts 'error'
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      eval {
        1 / 0
      };
      if ($@ && $@->isa("ZeroDivisionError")) {
        my $e = $@;
        print($e . "\\n");
      }

    EXPECTED
      begin
        1 / 0
      rescue ZeroDivisionError => e
        puts e
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      eval {
        1 / 0
      };
      if ($@ && $@->isa("ZeroDivisionError")) {
        print("zero division" . "\\n");
      }
      else if ($@ && $@->isa("Exception")) {
        print("exception" . "\\n");
      }

    EXPECTED
      begin
        1 / 0
      rescue ZeroDivisionError
        puts 'zero division'
      rescue Exception
        puts 'exception'
      end
    ACTUAL
  end

  def test_generate_case
    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my $val = undef;
      if ($val eq "abc") {
        print("abc" . "\\n")
      }
      elsif ($val == 123) {
        print("123" . "\\n")
      }
      elsif ($val eq "def" || $val == 456) {
        print("def456" . "\\n")
      }
      else {
        print("else" . "\\n")
      }
    EXPECTED
      val = nil
      case val
      when 'abc'
        puts 'abc'
      when 123 
        puts "#{123}"
      when 'def', 456
        puts "def456"
      else
        puts 'else'
      end
    ACTUAL
  end

  def test_generate_while
    assert_code <<-EXPECTED, <<-ACTUAL
      while (true) {
        do_something();
      }
    EXPECTED
      while (true)
        do_something
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      my $count = 0;
      while (true) {
        do_something();
        $count = $count + 1;
        if (5 < $count) {
          last;
        }

      }
    EXPECTED
      count = 0
      while (true)
        do_something
        count += 1
        break if 5 < count ;
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      while (true) {
        do_something();
        next;
      }
    EXPECTED
      while (true)
        do_something
        next
      end
    ACTUAL
  end

  def test_generate_until
    assert_code <<-EXPECTED, <<-ACTUAL
      my $count = 0;
      until (2 <= $count) {
        do_something();
        $count = $count + 1;
      }
    EXPECTED
      count = 0
      until (2 <= count)
        do_something
        count += 1
      end
    ACTUAL
  end

  def test_generate_scope
    assert_code <<-EXPECTED, <<-ACTUAL
      my $var1 = 0;
      if (true) {
        $var1 = 1;
        my $var2 = 2;
      }
    EXPECTED
      var1 = 0
      if true
        var1 = 1
        var2 = 2
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      my $var = 0;
      if (true) {
        $var = ()
      }
    EXPECTED
      var = 0
      if true
        var = []
      end
    ACTUAL


    assert_code <<-EXPECTED, <<-ACTUAL
      my $var1 = 0;
      while (true) {
        $var1 = 1;
        my $var2 = 2;
      }
    EXPECTED
      var1 = 0
      while true
        var1 = 1
        var2 = 2
      end
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my $var1 = 0;
      while (true) {
        $var1 = 1;
        my $var2 = 2;
        if (true) {
          $var1 = 2;
          $var2 = 3;
          my $var3 = 3;
        }

      }

      my $var3 = 0;
    EXPECTED
      var1 = 0
      while true
        var1 = 1
        var2 = 2
        if true
          var1 = 2
          var2 = 3
          var3 = 3
        end
      end
      var3 = 0
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      {
        package Foo;
        my $bar = undef;
        sub buzz {
          my $self = shift;
          $bar = "xyzzy";
        }

      }
    EXPECTED
      class Foo
        bar = nil
        def buzz
          bar = 'xyzzy'
        end
      end
    ACTUAL

=begin
    assert_code <<-EXPECTED, <<-ACTUAL
      {
        package Foo;
        my $bar = "12345";
        sub buzz {
          my $self = shift;
          0 + $bar
        }

      }
    EXPECTED
      class Foo
        bar = '12345'
        def buzz
          bar.to_i
        end
      end
    ACTUAL
=end
  end

  def test_generate_defun
    assert_code <<-EXPECTED, <<-ACTUAL
      sub foo {
        my $bar = shift;
        my $buzz = shift;
        print($bar . "\\n");
        print($buzz . "\\n");
      }
    EXPECTED
      def foo(bar, buzz)
        puts bar
        puts buzz
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      sub foo {
        my $bar = shift || 1;

      }
    EXPECTED
      def foo(bar=1)
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      sub foo {
        my $bar = shift;
        my @buzz = @_;
        print($bar . "\\n");
        print($buzz[0] . "\\n");
      }
    EXPECTED
      def foo(bar, *buzz)
        puts bar
        puts buzz[0]
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      sub foo {
        my @bar = @_;
        my $buzz = $bar[0];
        my $xyzzy = $bar[1];

      }
    EXPECTED
      def foo(*bar)
        buzz, xyzzy = *bar
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      sub foo {
        my $block = shift;
        $block->(1, 2, 3);
      }
    EXPECTED
      def foo(&block)
        block.call 1, 2, 3
      end
    ACTUAL
  end

  def test_generate_funcall
    assert_code <<-EXPECTED.strip, <<-ACTUAL
      func(arg1(), arg2());
    EXPECTED
      func arg1, arg2
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my $arg2 = undef;
      func(arg1(), $arg2);
    EXPECTED
      arg2 = nil
      func arg1, arg2
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my $arg2 = undef;
      my $arg3 = undef;

      func(arg1(), $arg2);
    EXPECTED
      arg2, arg3 = nil, nil
      func arg1, arg2
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      outer(inner(arg1(), arg2()));
    EXPECTED
      outer inner(arg1, arg2)
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      my @ary = ();
      for my $e (@ary) {
        print($e . "\\n");
      }
    EXPECTED
      ary = []
      ary.each do |e|
        puts e
      end
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      sub func {
        my $block = shift;
        $block->(1, 2);
      }

      func(sub {
          my $arg1 = shift;
          my $arg2 = shift;
          my $arg3 = $arg1 + $arg2;
        }
      );
    EXPECTED
      def func(&block)
        block.call 1, 2
      end
      func do |arg1, arg2|
        arg3 = arg1 + arg2
      end
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      sub func {
        my $arg1 = shift;
        my $arg2 = shift;
        my $block = shift;
        $block->($arg1, $arg2);
      }

      func(arg1(), arg2(), sub {
          my $arg3 = shift;
          my $arg4 = shift;
          my $arg5 = $arg3 + $arg4;
        }
      );
    EXPECTED
      def func(arg1, arg2, &block)
        block.call arg1, arg2
      end
      func arg1, arg2 do |arg3, arg4|
        arg5 = arg3 + arg4
      end
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my $a = 1;
      my $b = -($a);
      my $c = true;
      my $d = !($c);
      func(-($b), !($d));
    EXPECTED
      a = 1
      b = -a
      c = true
      d = !c
      func -b, !d
    ACTUAL
  end

  def test_generate_funcall_print
    assert_code <<-EXPECTED.strip, <<-ACTUAL
      print "Hello";
    EXPECTED
      STDOUT.print 'Hello'
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      print "Hello";
    EXPECTED
      $stdout.print 'Hello'
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      print STDERR "Hello";
    EXPECTED
      STDERR.print 'Hello'
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      print STDERR "Hello";
    EXPECTED
      $stderr.print 'Hello'
    ACTUAL
  end

  def test_generate_funcall_special
    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my $var = 1;
      ("" . $var);
    EXPECTED
      var = 1
      var.to_s
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my @var = ();
      my $other = undef;
      push(@var, @{$other});
    EXPECTED
      var = []
      other = nil
      var.push other
    ACTUAL

    assert_code '__PACKAGE__->hello();', 'self.class.hello'

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my $var = undef;
      (ref $var eq 'ARRAY');
    EXPECTED
      var = nil
      var.is_a? Array
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      BEGIN {
        some_initialization();
      }
    EXPECTED
      __BEGIN__ do
        some_initialization
      end
    ACTUAL
  end

  def test_generate_class
    assert_code <<-EXPECTED, <<-ACTUAL
      {
        package Foo;
        use base 'Bar';
        sub buzz {
          my $self = shift;

        }

      }
    EXPECTED
      class Foo < Bar
        def buzz
        end
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      {
        package Foo;
        use base 'Bar';
        __PACKAGE__->call_class_method();
        sub buzz {
          my $self = shift;

        }

      }
    EXPECTED
      class Foo < Bar
        self.call_class_method
        def buzz
        end
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      {
        package Foo;
        use base 'Bar';
        __PACKAGE__->call_class_method();
        sub buzz {


        }

      }
    EXPECTED
      class Foo < Bar
        self.call_class_method
        def buzz(__no_self__)
        end
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      {
        package Foo;
        use base 'Bar';
        __PACKAGE__->call_class_method()->call_class_method();
      }
    EXPECTED
      class Foo < Bar
        self.call_class_method.call_class_method
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      {
        package Foo;
        use base 'Bar';
        extends "Buzz";
      }
    EXPECTED
      class Foo < Bar
        extends Buzz
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      {
        package Foo;
        use base 'Bar';
        extends "Buzz::Xyzzy";
      }
    EXPECTED
      class Foo < Bar
        extends Buzz::Xyzzy
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      {
        package Foo;
        use base "Bar";
      }
    EXPECTED
      class Foo
        extend 'Bar'
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      {
        package Foo;
        use base "Buzz::Xyzzy";
      }
    EXPECTED
      class Foo
        extend Buzz::Xyzzy
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      {
        package Foo;
        __PACKAGE__->bar("key", sub {
            my $self = shift;
            $self->buzz();
          }
        );
      }
    EXPECTED
      class Foo
        self.bar 'key', ->(__self__) {
          self.buzz
        }
      end
    ACTUAL

=begin
    assert_code <<-EXPECTED, <<-ACTUAL
      {
        package Foo;
        use base 'Bar';
        my $foo = undef;
        sub method {
          my $self = shift;
          my $bar = $foo;
        }

      }
    EXPECTED
      class Foo < Bar
        foo = nil
        def method
          bar = foo
        end
      end
    ACTUAL
=end
  end

  def test_generate_module
    assert_code <<-EXPECTED, <<-ACTUAL
      {
        package Abc::Gef::A;

      }
    EXPECTED
      module Abc
        module Gef
          class A
          end
        end
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      {
        package Abc::Def::Jkl::Mno::B;

      }
    EXPECTED
      module Abc
        module Def
          module Jkl::Mno
            class B
            end
          end
        end
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      {
        package Buzz::Xyzzy::Abc::Foo;

      }
    EXPECTED
      module Buzz::Xyzzy::Abc
        class Foo
        end
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      {
        package Buzz::Xyzzy::Abc::Bar;
        use base 'Buzz::Xyzzy::Abc::Foo';

      }
    EXPECTED
      module Buzz::Xyzzy::Abc
        class Bar < Foo
        end
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      {
        package Fuga;
        use base 'Buzz::Xyzzy::Abc::Foo';

      }
    EXPECTED
      module Buzz::Xyzzy::Abc
        class ::Fuga < Foo
        end
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      {
        package Buzz::Xyzzy::Abc::Piyo;
        use base 'Foo';

      }
    EXPECTED
      module Buzz::Xyzzy::Abc
        class Piyo < ::Foo
        end
      end
    ACTUAL
  end

  def test_generate_inline_perl # symbol
    assert_code <<-EXPECTED, <<-ACTUAL
      sub func {
        my $i = shift;
        for ($i = 0; $i <= 9; $i++) {
          print "$i\\n";
        }
      }
    EXPECTED
      def func(i)
        %s{
          for ($i = 0; $i <= 9; $i++) {
            print "$i\\n";
          }
        }
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      sub func {
        my $i = shift;
        for ($i = 0; $i <= 9; $i++) {
          print "$i\n";
        }
        print("hello" . "\\n");
      }
    EXPECTED
      def func(i)
        %x{
          for ($i = 0; $i <= 9; $i++) {
            print "$i\\n";
          }
        }
        puts 'hello'
      end
    ACTUAL
  end
end

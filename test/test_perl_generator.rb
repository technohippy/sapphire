require "test/unit"
require "sapphire/perl_generator"

=begin
TEMPLATE:
    assert_code <<-EXPECTED, <<-ACTUAL
    EXPECTED
    ACTUAL
=end

class TestPerlGenerator < Test::Unit::TestCase
  def setup
    @generator = Sapphire::PerlGenerator.new nil, nil
  end

  def assert_code(expected, actual)
    assert_equal expected.gsub(/^ +/, ''), @generator.generate(actual)
  end

  def test_generate_general
    assert_code '1 + 1;', '1 + 1'
    assert_code 'method_call("abc");', 'method_call "abc"'
    assert_code 'inner(outer("abc"));', 'inner outer("abc")'
    assert_code 'my $var = 1;', 'var = 1'
    assert_code 'my @ary = (1, 2, 3);', 'ary = [1, 2, 3]'
    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my $var = "foo";
      $var = "bar";
    EXPECTED
      var = 'foo'
      var = 'bar'
    ACTUAL
  end

  def test_generate_defun
    assert_code <<-EXPECTED, <<-ACTUAL
      sub foo {
        my $bar = shift;
        print($bar . "\\n");
      }
    EXPECTED
      def foo(bar)
        puts bar
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
  end

  def test_generate_module
    assert_code <<-EXPECTED, <<-ACTUAL
      {
        package Abc::Gef::A;
        use base 'Class::Accessor::Fast';

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
        use base 'Class::Accessor::Fast';

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
        use base 'Class::Accessor::Fast';

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
end

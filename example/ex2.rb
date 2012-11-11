# module and class
module Abc
  module Def
    module Ghi
      class A
      end
    end

    module Jkl::Mno
      class B
      end
    end
  end
end

module Buzz::Xyzzy::Abc
  class Foo
  end

  class Bar < Foo
  end

  class ::Fuga < Foo
  end

  class Piyo < ::Foo
  end
end

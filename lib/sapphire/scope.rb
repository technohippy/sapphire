module Sapphire
  class Scope
    attr_accessor :module

    def initialize(parent=NilScope.new)
      @parent = parent
      @variable_names = []
      @method_names = []
    end

    def all_modules
      if self.module
        @parent.all_modules + [self.module]
      else
        @parent.all_modules
      end
    end

    def create_child
      self.class.new self
    end

    def define_variable(variable_name)
      @variable_names.push variable_name.to_sym
    end

    def define_method(method_name)
      @method_names.push method_name.to_sym
    end

    def variable_defined?(variable_name)
      @variable_names.include?(variable_name.to_sym) || @parent.variable_defined?(variable_name)
    end

    def method_defined?(method_name)
      @method_names.include?(method_name.to_sym) || @parent.method_defined?(method_name)
    end
  end

  class NilScope < Scope
    def initialize
      super nil
    end

    def all_modules
      []
    end

    def variable_defined?(variable_name)
      false
    end

    def method_defined?(method_name)
      false
    end
  end
end

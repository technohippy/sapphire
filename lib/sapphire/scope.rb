module Sapphire
  class Scope
    VarDef = Struct.new :name, :type # type should be :ref (default), :array or :hash

    attr_accessor :module

    def initialize(parent=NilScope.new)
      @parent = parent
      @constant_names = []
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

    def define_constant(constant_name, type=:ref)
      @constant_names.push VarDef.new(constant_name.to_sym, type)
    end

    def constant_defined?(constant_name)
      (not @constant_names.find{|defs| defs.name == constant_name}.nil?) || @parent.constant_defined?(constant_name)
    end

    def constant_definition(constant_name)
      var_def = @constant_names.find{|defs| defs.name == constant_name}
      var_def ? var_def : @parent.constant_definition(constant_name)
    end

    def define_variable(variable_name, type=:ref)
      @variable_names.push VarDef.new(variable_name.to_sym, type)
    end

    def variable_defined?(variable_name)
      (not @variable_names.find{|defs| defs.name == variable_name}.nil?) || @parent.variable_defined?(variable_name)
    end

    def variable_definition(variable_name)
      var_def = @variable_names.find{|defs| defs.name == variable_name}
      var_def ? var_def : @parent.variable_definition(variable_name)
    end

    def define_method(method_name)
      @method_names.push method_name.to_sym
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

    def constant_defined?(variable_name)
      false
    end

    def constant_definition(constant_name)
      nil
    end

    def variable_defined?(variable_name)
      false
    end

    def variable_definition(variable_name)
      nil
    end

    def method_defined?(method_name)
      false
    end
  end
end

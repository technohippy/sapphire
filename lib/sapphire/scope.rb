require 'sapphire/variable_def'

module Sapphire
  class Scope
    attr_accessor :module

    Global = self.new

    def initialize(parent=NilScope.new)
      @parent = parent
      @constant_names = []
      @variable_names = []
      @method_names = []

      # TODO: should be defined in Global
      self.define_constant :ENV, :hash
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
      define = VariableDef.new(constant_name.to_sym, type)
      @constant_names.push define
      define
    end

    def constant_defined?(constant_name)
      (not @constant_names.find{|defs| defs.name == constant_name}.nil?) || @parent.constant_defined?(constant_name)
    end

    def constant_definition(constant_name)
      var_def = @constant_names.find{|defs| defs.name == constant_name}
      var_def ? var_def : @parent.constant_definition(constant_name)
    end

    def define_variable(variable_name, type=:ref)
      @variable_names.push VariableDef.new(variable_name.to_sym, type)
    end

    def variable_defined?(variable_name)
      (not @variable_names.find{|defs| defs.name.to_s == variable_name.to_s}.nil?) || @parent.variable_defined?(variable_name)
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

  class CombinedScope < Scope
    def initialize(primary, secondary)
      @primary = primary
      @secondary = secondary
    end

    def all_modules
      # TODO
      @primary.all_modules + @secondary.all_modules
    end

    def constant_defined?(variable_name)
      @primary.constant_defined?(variable_name) || @secondary.constant_defined?(variable_name)
    end

    def constant_definition(constant_name)
      const_def = @primary.constant_definition constant_name
      if const_def.nil?
        @secondary.constant_definition constant_name
      else
        const_def
      end
    end

    def variable_defined?(variable_name)
      @primary.variable_defined?(variable_name) || @secondary.variable_defined?(variable_name)
    end

    def variable_definition(variable_name)
      var_def = @primary.variable_definition variable_name
      if var_def.nil?
        @secondary.variable_definition variable_name
      else
        var_def
      end
    end

    def method_defined?(method_name)
      @primary.method_defined?(method_name) || @secondary.method_defined?(method_name)
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
      NullVariableDef.new
    end

    def variable_defined?(variable_name)
      false
    end

    def variable_definition(variable_name)
      NullVariableDef.new
    end

    def method_defined?(method_name)
      false
    end
  end
end

module Sapphire
  class VariableDef
    attr_reader :name, :type

    # type should be :ref (default), :array, :hash or :block
    def initialize(name, type=:ref)
      @name = name
      @type = type || :ref
    end

    def sigil
      @type == :array ? '@' : '$'
    end
  end
end

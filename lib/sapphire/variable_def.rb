module Sapphire
  class VariableDef
    attr_reader :name, :kind, :type

    # kind should be :ref (default), :array, :hash or :block
    def initialize(name, kind=:ref, type=nil)
      @name = name
      @kind = kind || :ref
      @type = type
    end

    def sigil
      @kind == :array ? '@' : '$'
    end
  end
end

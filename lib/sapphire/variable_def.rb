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
      case @kind
      when :array; '@'
      when :hash;  '%'
      when :block; '&'
      when :glob;  '*'
      else;        '$'
      end
    end
  end

  class NullVariableDef < VariableDef
    def initialize
    end

    def sigil
      '$'
    end

    def is_nil?
      true
    end
  end
end

require 'sapphire/parser'
require 'sapphire/node'

module Sapphire
  class Generator
    attr_reader :root_node, :prefix, :suffix

    def initialize(prefix=nil, suffix=nil)
      @prefix = prefix
      @suffix = suffix
    end

    def generate(string_or_node)
      @root_node = string_or_node.is_a?(String) ? Parser.new.parse(string_or_node) : string_or_node
      @root_node.setup
      "#{@prefix}#{generate_body}#{@suffix}"
    end
  end
end

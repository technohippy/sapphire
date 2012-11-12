require 'sapphire/node'

module Sapphire
  class Generator
    attr_reader :root_node

    def initialize(root_node)
      @root_node = root_node
    end
  end
end

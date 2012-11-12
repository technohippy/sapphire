require 'ruby_parser'
require 'sapphire/node'
require 'pp'

module Sapphire
  class Parser
    def parse(string)
      root_node = instance_eval RubyParser.new.parse(string).inspect
      root_node.setup_scope
    end

    private

    def to_node(type, *args)
      eval("::Sapphire::Node::#{type.to_s.capitalize}Node").new *args
    end
    alias s to_node
  end
end

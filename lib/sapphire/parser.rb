require 'ruby_parser'
require 'sapphire/node'
require 'pp'

module Sapphire
  class Parser
    def parse(string)
      root_node = instance_eval RubyParser.new.parse(string).inspect
      root_node.setup
    end

    private

    def camelize(string)
      string.capitalize.gsub(/_([a-z])/){$1.upcase}
    end

    def to_node(type, *args)
      eval("::Sapphire::Node::#{camelize type.to_s}Node").new *args
    end
    alias s to_node
  end
end

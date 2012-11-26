require 'sapphire/scope'

module Sapphire
  module Node
    class Base
      attr_accessor :parent, :arguments, :scope

      def self.args_reader(*names)
        names.each_with_index do |name, i|
          self.class_eval <<-EOS
            def #{name}
              @#{name} ||= @arguments[#{i}]
            end
          EOS
        end
      end

      def self.body_reader(range=1..-1)
        self.class_eval <<-EOS
          def body
            body = BlockNode.new *@arguments[#{range.inspect}]
            body.parent = self
            body
          end
        EOS
      end

      def initialize(*arguments)
        (@arguments = arguments).each {|arg| arg.parent = self if arg.is_a? Base}
      end

      def first
        @arguments[0]
      end

      def [](idx)
        @arguments[idx]
      end

      def []=(idx, val)
        @arguments[idx] = val
      end

      def next(step=1)
        raise 'step must be more than zero.' unless 0 < step

        @parent.arguments.each_with_index do |arg, i|
          return @parent.arguments[i+step] if arg == self
        end
        nil
      end

      def setup(scope=Scope.new)
        @scope = scope
        @arguments.each do |arg|
          arg.setup scope if arg.is_a? Base
        end
        _setup
        self
      end

      def _setup
        # for subclasses
      end

      def to_s
        "#{self.class.name}(#{@arguments.map(&:to_s).join(', ')})"
      end
    end

    class KeywordBase < Base
      def self.set_keyword(name)
        self.class_eval <<-EOS
          def keyword
            #{name.inspect}
          end
        EOS
      end
    end

    class ScopedBase < Base
      def setup(scope=Scope.new)
        super scope.create_child
      end
    end

    class BlockNode < Base
    end

    class IterNode < Base
      body_reader 2..-1
    end

    class CallNode < Base
      args_reader :receiver, :method_name

      def arglist
        @arguments[2..-1]
      end
    end

    class ArrayNode < Base
    end

    class LitNode < Base
      args_reader :value
    end

    class LasgnNode < Base
      args_reader :var_name, :value
    end

    class DefnNode < ScopedBase
      args_reader :method_name, :method_args
      body_reader 2..-1

      def _setup
        @scope.define_method method_name
      end
    end

    class ArgsNode < Base
    end

    class ScopeNode < ScopedBase
    end

    class ClassNode < Base
      args_reader :class_name, :super_class
      body_reader 2..-1
    end

    class ConstNode < Base
      args_reader :const_name
    end

    class AttrasgnNode < Base
      args_reader :receiver, :method_name, :value
    end

    class StrNode < Base
      args_reader :value
    end

    class LvarNode < Base
      args_reader :var_name
    end

    class ModuleNode < ScopedBase
      args_reader :module_name
      body_reader

      def _setup
        @scope.module = self.module_name
      end
    end

    class Colon2Node < Base
      args_reader :head, :tail
    end

    class Colon3Node < Base
      attr_reader :head # always nil
      args_reader :tail
    end

    class ReturnNode < Base
      args_reader :value
    end

    class IfNode < ScopedBase
      args_reader :condition, :ok_body, :ng_body
    end

    class AndNode < Base
      args_reader :left, :right
    end

    class OrNode < Base
      args_reader :left, :right
    end

    class HashNode < Base
    end

    class Match3Node < Base
      args_reader :regexp, :target
    end

    class GvarNode < Base
      args_reader :gvar_name
    end

    class NotNode < Base
    end

    class CdeclNode < Base
      args_reader :const_name, :value

      def _setup
        @scope.define_constant const_name, self.value.is_a?(ArrayNode) ? :array : :ref
      end
    end

    class MasgnNode < Base
      args_reader :lasgns, :values
    end

    class SplatNode < Base
      args_reader :value
    end

    class WhileNode < ScopedBase
      args_reader :condition
      body_reader 1..-2
    end

    class UntilNode < ScopedBase
      args_reader :condition
      body_reader 1..-2
    end

    class SelfNode < KeywordBase
      set_keyword '$self'
    end

    class BreakNode < KeywordBase
      set_keyword 'break;'
    end

    class NextNode < KeywordBase
      set_keyword 'next;'
    end

    class NilNode < KeywordBase
      set_keyword 'undef'
    end

    class TrueNode < KeywordBase
      set_keyword 'true'
    end

    class FalseNode < KeywordBase
      set_keyword 'false'
    end

    class DstrNode < Base
      args_reader :str
    end

    class EvstrNode < Base
      args_reader :expression
    end

    class RescueNode < Base
      args_reader :body

      def rescue_bodies
        @arguments[1..-1]
      end
    end

    class ResbodyNode < Base
      args_reader :array
      body_reader 1..-1

      def rescue_args
        array.arguments
      end

      def exception_class
        if rescue_args.first.is_a? ConstNode
          rescue_args.first.const_name
        else
          nil
        end
      end

      def exception_name
        if rescue_args.last.is_a? LasgnNode
          rescue_args.last.var_name
        else
          nil
        end
      end
    end

    class BlockPassNode < Base
    end

    class ToAryNode < Base
    end
  end
end

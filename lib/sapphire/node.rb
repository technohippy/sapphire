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

      def initialize(*arguments)
        (@arguments = arguments).each {|arg| arg.parent = self if arg.is_a? Base}
      end

      def first
        @arguments[0]
      end

      def next(step=1)
        raise 'step must be more than zero.' unless 0 < step

        @parent.arguments.each_with_index do |arg, i|
          return @parent.arguments[i+step] if arg == self
        end
        nil
      end

      def setup_scope(scope=Scope.new)
        @scope = scope
        @arguments.each do |arg|
          arg.setup_scope scope if arg.is_a? Base
        end
        self
      end

      def to_s
        "#{self.class.name}(#{@arguments.map(&:to_s).join(', ')})"
      end
    end

    class ScopedBase < Base
      def setup_scope(scope=Scope.new)
        super scope.create_child
      end
    end

    class BlockNode < Base
    end

    class IterNode < Base
    end

    class CallNode < Base
      #args_reader :receiver, :method_name, :arglist
      args_reader :receiver, :method_name

      def arglist # TODO
        ArglistNode.new *@arguments[2..-1]
      end
    end

    class ArrayNode < Base
    end

    class LitNode < Base
      args_reader :value
    end

    class ArglistNode < Base
    end

    class LasgnNode < Base
      args_reader :var_name, :value
    end

    class DefnNode < ScopedBase
      #args_reader :method_name, :method_args, :body
      args_reader :method_name, :method_args

      def body # TODO
        body = BlockNode.new *@arguments[2..-1]
        body.parent = self
        body
      end

      def setup_scope(scope=Scope.new)
        super
        @scope.define_method method_name
        self
      end
    end

    class ArgsNode < Base
    end

    class ScopeNode < ScopedBase
    end

    class ClassNode < Base
      #args_reader :class_name, :super_class, :body
      args_reader :class_name, :super_class

      def body # TODO
        body = BlockNode.new *@arguments[2..-1]
        body.parent = self
        body
      end
    end

    class ConstNode < Base
      args_reader :const_name
    end

    class AttrasgnNode < Base
      args_reader :receiver, :method_name, :arglist
    end

    class StrNode < Base
      args_reader :value
    end

    class LvarNode < Base
      args_reader :var_name
    end

    class NilNode < Base
    end

    class ModuleNode < ScopedBase
      #args_reader :module_name, :body
      args_reader :module_name

      def setup_scope(scope=Scope.new)
        super
        @scope.module = self.module_name
        self
      end

      def body # TODO
        body = BlockNode.new *@arguments[1..-1]
        body.parent = self
        body
      end
    end

    class Colon2Node < Base
      args_reader :head, :tail
    end

    class Colon3Node < Base
      attr_reader :head # always nil
      args_reader :tail
    end

    class SelfNode < Base
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

      def setup_scope(scope=Scope.new)
        super
        @scope.define_constant const_name
        self
      end
    end

    class MasgnNode < Base
      args_reader :lasgns, :values
    end

    class SplatNode < Base
      args_reader :value
    end
  end
end

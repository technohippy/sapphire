require 'sapphire/scope'

class Object
  def const_node?(name)
    false
  end

  def gvar_node?(name)
    false
  end
end

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
            body = BlockNode.new(*@arguments[#{range.inspect}])
            body.parent = self
            body
          end
        EOS
      end

      def self.set_kind(kind)
        self.class_eval <<-EOS
          def kind
            @kind ||= #{kind.inspect}
          end
        EOS
      end


      def initialize(*arguments)
        @kind = nil
        (@arguments = arguments).each {|arg| arg.parent = self if arg.is_a? Base}
      end

      def kind
        @kind || default_kind
      end

      def kind=(t)
        @kind = t
      end

      def default_kind
        :ref
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

    class AsgnBase < Base
    end

    class ScopedBase < Base
      def setup(scope=Scope.new)
        super scope.create_child
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

    class AndNode < Base
      args_reader :left, :right
    end

    class ArglistNode < Base
    end

    class ArgsNode < Base
    end

    class ArrayNode < Base
      set_kind :array
    end

    class AttrasgnNode < AsgnBase
      args_reader :receiver, :method_name, :value
    end

    class BlockNode < ScopedBase
    end

    class BlockPassNode < Base
    end

    class BreakNode < KeywordBase
      set_keyword 'last;'
    end

    class CallNode < Base
      args_reader :receiver, :method_name

      def arglist
        @arguments[2..-1]
      end

      def kind
        @kind ||= 
          case self.method_name
          when :map, :split; :array
          when :to_hash;     :hash
          when :to_glob;     :glob
          else               super
          end
      end
    end

    class CaseNode < Base
      args_reader :var_name
    end

    class CdeclNode < Base
      args_reader :const_name, :value

      def _setup
        @scope.define_constant const_name, self.value.is_a?(ArrayNode) ? :array : :ref
      end
    end

    class ClassNode < Base
      args_reader :class_name, :super_class
      body_reader 2..-1

      def setup(scope=Scope.new)
        super_class_scope = Scope.new # TODO
        @scope = CombinedScope.new super_class_scope, scope
        @arguments.each do |arg|
          arg.setup scope if arg.is_a? Base
        end
        _setup
        self
      end
    end

    class Colon2Node < Base
      args_reader :head, :tail
    end

    class Colon3Node < Base
      attr_reader :head # always nil
      args_reader :tail
    end

    class ConstNode < Base
      args_reader :const_name

      def const_node?(name)
        name == self.const_name
      end
    end

    class CvarNode < Base
      args_reader :name

      def cvar_name
        self.first.to_s[2..-1].to_sym
      end
      alias var_name cvar_name
    end

    class CvasgnNode < AsgnBase
      args_reader :name, :value

      def cvar_name
        self.first.to_s[2..-1].to_sym
      end
      alias var_name cvar_name
    end

    class CvdeclNode < Base
      args_reader :name, :value

      def cvar_name
        self.first.to_s[2..-1].to_sym
      end
      alias var_name cvar_name
    end

    class DefinedNode < KeywordBase
    end

    class DefnNode < ScopedBase
      args_reader :method_name, :method_args
      body_reader 2..-1

      def _setup
        @scope.define_method method_name
# TODO
=begin
        if @scope.parent && !@scope.parent.is_a?(NilScope)
          @scope.parent.define_method method_name
        else
          @scope.define_method method_name
        end
=end
      end
    end

    class Dot2Node < Base
      args_reader :min, :max
    end

    class DstrNode < Base
      args_reader :str
    end

    class EvstrNode < Base
      args_reader :expression
    end

    class FalseNode < KeywordBase
      set_keyword 'false'
    end

    class GasgnNode < AsgnBase
      args_reader :gvar_name, :value
    end

    class GvarNode < Base
      args_reader :gvar_name

      def gvar_node?(name)
        name == self.gvar_name
      end
    end

    class HashNode < Base
      #set_kind :hash
    end

    class IfNode < ScopedBase
      args_reader :condition, :ok_body, :ng_body
    end

    class IterNode < Base
      body_reader 2..-1

      def kind
        @kind ||= (self.first.is_a?(CallNode) && self.first.method_name == :map ? :array : super)
      end
    end

    class IvarNode < Base
      args_reader :ivar_name

      def kind
        @kind ||= self.ivar_name == :@_ ? :array : super
      end
    end

    class LasgnNode < AsgnBase
      args_reader :var_name, :value
    end

    class LitNode < Base
      args_reader :value
    end

    class LvarNode < Base
      args_reader :var_name

      def kind
        if @kind
          @kind
        else
          var_def = self.scope.variable_definition self.var_name
          @kind = var_def ? var_def.kind : super
        end
      end
    end

    class MasgnNode < AsgnBase
      args_reader :lasgns, :values
    end

    class Match3Node < Base
      args_reader :regexp, :target
    end

    class ModuleNode < ScopedBase
      args_reader :module_name
      body_reader

      def _setup
        @scope.module = self.module_name
      end
    end

    class NextNode < KeywordBase
      set_keyword 'next;'
    end

    class NilNode < KeywordBase
      set_keyword 'undef'
    end

    class NotNode < Base
    end

    class NthRefNode < KeywordBase
      def keyword
        "$#{self.first}"
      end
    end

    class OpAsgn1Node < AsgnBase
      args_reader :receiver, :arglist, :op, :value 
    end

    class OpAsgnOrNode < AsgnBase
      args_reader :receiver, :lasgn
      
      def value
        self.lasgn.value
      end
    end

    class OrNode < Base
      args_reader :left, :right
    end

    class PostexeNode < Base
    end

    class ReturnNode < Base
      args_reader :value
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

    class RescueNode < Base
      args_reader :body

      def rescue_bodies
        @arguments[1..-1]
      end
    end

    class ScopeNode < ScopedBase
    end

    class SelfNode < KeywordBase
      set_keyword '$self'
    end

    class SplatNode < Base
      args_reader :value
    end

    class StrNode < Base
      args_reader :value
    end

    class ToAryNode < Base
    end

    class TrueNode < KeywordBase
      set_keyword 'true'
    end

    class UntilNode < ScopedBase
      args_reader :condition
      body_reader 1..-2
    end

    class WhenNode < ScopedBase
      args_reader :expected_values
      body_reader
    end

    class WhileNode < ScopedBase
      args_reader :condition
      body_reader 1..-2
    end

    class XstrNode < Base
      args_reader :value
    end

    class ZsuperNode < KeywordBase
      set_keyword '$self->SUPER'
    end
  end
end

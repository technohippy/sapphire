require 'sapphire/generator'
require 'sapphire/node'

module Sapphire
  class PerlGenerator < Generator
    def generate
      @root_node.setup_scope
      "use strict;\nuse warnings;\n\n#{obj_to_perl @root_node}\n1;"
    end

    def obj_to_perl(obj)
      case obj
      when Node::IterNode
        obj_to_perl obj.first
      when Node::CallNode
        call_node_to_perl obj
      when Node::ArrayNode
        "(#{obj.arguments.map {|a| obj_to_perl a}.join(', ')})"
      when Node::LitNode
        obj.value.inspect
      when Node::LasgnNode
        lasgn_node_to_perl obj
      when Node::DefnNode
        defn_node_to_perl obj
      when Node::ArgsNode
        obj.arguments.map {|a| obj_to_perl a}.join(', ')
      when Node::ClassNode
        class_node_to_perl obj
      when Node::ConstNode
        obj.const_name.to_s
      when Node::AttrasgnNode
        attrasgn_node_to_perl obj
      when Node::StrNode
        obj.value.inspect
      when Node::LvarNode
        "$#{obj.var_name}"
      when Node::NilNode
        "nil"
      when Node::ModuleNode
        obj_to_perl obj.body
      when Node::Colon2Node
        "#{obj_to_perl obj.head}::#{obj_to_perl obj.tail}"
      when Node::Colon3Node
        obj_to_perl obj.tail
      when Node::SelfNode
        '$self'
      when Node::ReturnNode
        "return #{obj_to_perl obj.value};"
      when Node::IfNode
        if_node_to_perl obj
      when Node::AndNode
        "#{obj_to_perl obj.left} and #{obj_to_perl obj.right}"
      when Node::HashNode
        hash_node_to_perl obj
      when Node::Match3Node
        "#{obj_to_perl obj.target} =~ #{obj_to_perl obj.regexp}"
      when Node::GvarNode
        obj.gvar_name.to_s
      when Node::NotNode
        "not #{obj_to_perl obj.first}"
      when Node::Base
        obj.arguments.map {|a| obj_to_perl a}.join("\n")
      else
        obj.to_s
      end
    end

    def call_node_to_perl(call_node)
      semicolon = call_node.parent.nil? || call_node.parent.is_a?(Node::BlockNode) || 
        (call_node.parent.is_a?(Node::IterNode) && call_node.parent.parent.is_a?(Node::BlockNode)) ? 
          ';' : ''
      if call_node.receiver && call_node.method_name == :each
        var_name = call_node.next.arguments.first
        my = call_node.scope.variable_defined?(var_name) ? '' : 'my '
        <<-EOS.gsub(/^ +/, '')
          for #{my}$#{var_name} #{obj_to_perl call_node.receiver} {
            #{obj_to_perl call_node.next(2)}
          }
        EOS
      elsif call_node.receiver.nil? && call_node.method_name == :puts
        %Q|print(#{obj_to_perl call_node.arglist} . "\\n")#{semicolon}|
      elsif call_node.receiver.nil? && call_node.method_name == :require
        mod = call_node.arglist.first.value.to_s
        mod = mod.split('/').map{|e| e.capitalize.gsub(/_([a-z])/){$1.upcase}}.join '::'
        "use #{mod}#{semicolon}"
      elsif call_node.receiver.nil? && call_node.method_name == :attr_accessor
        "__PACKAGE__->mk_accessors(qw(#{call_node.arglist.arguments.map{|lit| 
          lit.value.to_s}.join(' ')}))#{semicolon}"
      elsif call_node.method_name == :[]
        "#{obj_to_perl call_node.receiver}->{#{obj_to_perl call_node.arglist.first}}#{semicolon}"
      elsif call_node.receiver && call_node.method_name == :size
        "(scalar call_node.{#{obj_to_perl call_node.receiver}})#{semicolon}"
      elsif call_node.receiver && call_node.method_name == :empty?
        "(scalar call_node.{#{obj_to_perl call_node.receiver}} == 0)#{semicolon}"
      elsif call_node.receiver && call_node.method_name == :to_arrayref # TODO: remove this
        "[#{obj_to_perl call_node.receiver}]#{semicolon}"
      elsif call_node.method_name == :map
        <<-EOS.gsub(/^ /, '')
          map {
            #{obj_to_perl call_node.next(2)}
          } #{obj_to_perl call_node.receiver}#{semicolon}
        EOS
      elsif call_node.receiver && [:find, :select].include?(call_node.method_name)
        "(grep { #{obj_to_perl call_node.next(2)} } call_node.{#{obj_to_perl call_node.receiver}}) != 0#{semicolon}"
      elsif call_node.method_name == :is_a?
        arg = obj_to_perl call_node.arglist.first
        if arg == 'Array'
          "(ref #{obj_to_perl call_node.receiver} eq 'ARRAY')#{semicolon}"
        else
          "(ref #{obj_to_perl call_node.receiver} eq '#{arg}')#{semicolon}"
        end
      else
        receiver = call_node.receiver ? "#{obj_to_perl call_node.receiver}->" : ''
        method = call_node.method_name.to_s
        args = call_node.arglist.arguments.map {|a| obj_to_perl a}.join(', ')
        "#{receiver}#{method}(#{args})#{semicolon}"
      end
    end

    def lasgn_node_to_perl(obj)
      if obj.scope.variable_defined? obj.var_name
        "$#{obj.var_name} = #{obj_to_perl obj.value};"
      else
        obj.scope.define_variable obj.var_name
        "my $#{obj.var_name} = #{obj_to_perl obj.value};"
      end
    end

    def defn_node_to_perl(obj)
      tmp_args = obj.method_args.arguments.dup

      klass = obj
      while (klass = klass.parent)
        break if klass.is_a? Node::ClassNode
      end
      tmp_args.unshift('self') if klass
      asgn_args = tmp_args.empty? ? 
        '' : 
        "\nmy (#{tmp_args.map{|s| "$#{s}"}.join(', ')}) = @_;"

      <<-EOS.gsub(/^ +/, '')
        sub #{obj.method_name} {#{asgn_args}
          #{obj_to_perl obj.body}
        }
      EOS
    end

    def class_node_to_perl(obj)
      fqcn = 
        if obj.class_name.is_a? Node::Colon3Node
          obj_to_node obj.class_name
        elsif obj.class_name =~ /^::(.+)/
          $1
        else
          (obj.scope.all_modules.dup + [obj.class_name]).map {|e| obj_to_perl e}.join '::'
        end
      super_fqcn =
        if obj.super_class.nil?
          'Class::Accessor::Fast'
        elsif obj.super_class.is_a? Node::Colon3Node
          obj_to_node obj.super_class
        elsif obj.super_class =~ /^::(.+)/
          $1
        else
          (obj.scope.all_modules.dup + [obj.super_class]).map {|e| obj_to_perl e}.join '::'
        end
      <<-EOS.gsub(/^ +/, '')
        {
          package #{fqcn};
          use base '#{super_fqcn}';
          #{obj_to_perl obj.body}
        }
      EOS
    end

    def attrasgn_node_to_perl(obj)
      receiver = obj.receiver.var_name
      attr = obj.method_name.to_s.sub('=', '')
      val = obj_to_perl obj.arglist
      "$#{receiver}->#{attr}(#{val});"
    end

    def if_node_to_perl(obj)
      if obj.ok_body
        (<<-EOK + (obj.ng_body ? <<-ENG : '')).gsub(/^ +/, '')
          if (#{obj_to_perl obj.condition}) {
            #{obj_to_perl obj.ok_body}
          }
        EOK
          else {
            #{obj_to_perl obj.ng_body}
          }
        ENG
      else
        <<-EOS.gsub /^ +/, ''
          unless (#{obj_to_perl obj.condition}) {
            #{obj_to_perl obj.ng_body}
          }
        EOS
      end
    end

    def hash_node_to_perl(obj)
      "{#{
        Hash[*obj.arguments].to_a.map do |k, v|
          "#{obj_to_perl k} => #{obj_to_perl v}"
        end.join ', '
      }}"
    end
  end
end

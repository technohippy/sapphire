require 'sapphire/generator'
require 'sapphire/node'

module Sapphire
  class PerlGenerator < Generator
    DEFAULT_PREFIX = "use 5.010;\nuse strict;\nuse warnings;\n"
    DEFAULT_SUFFIX = "\n1;"

    def initialize(prefix=DEFAULT_PREFIX, suffix=DEFAULT_SUFFIX)
      super
    end

    def generate_body
      obj_to_perl @root_node
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
        obj_to_perl obj.value
      when Node::LasgnNode
        lasgn_node_to_perl obj
      when Node::DefnNode
        defn_node_to_perl obj
      when Node::ArgsNode
        obj.arguments.map {|a| obj_to_perl a}.join(', ')
      when Node::ClassNode
        class_node_to_perl obj
      when Node::ConstNode
        const_node_to_perl obj
      when Node::AttrasgnNode
        attrasgn_node_to_perl obj
      when Node::StrNode
        obj.value.inspect
      when Node::LvarNode
        lvar_node_to_perl obj
      when Node::ModuleNode
        obj_to_perl obj.body
      when Node::Colon2Node
        "#{obj_to_perl obj.head}::#{obj_to_perl obj.tail}"
      when Node::Colon3Node
        obj_to_perl obj.tail
      when Node::ReturnNode
        "return #{obj_to_perl obj.value};"
      when Node::IfNode
        if_node_to_perl obj
      when Node::AndNode
        "#{obj_to_perl obj.left} and #{obj_to_perl obj.right}"
      when Node::OrNode
        "#{obj_to_perl obj.left} or #{obj_to_perl obj.right}"
      when Node::HashNode
        hash_node_to_perl obj
      when Node::Match3Node
        "#{obj_to_perl obj.target} =~ #{obj_to_perl obj.regexp}"
      when Node::GvarNode
        obj.gvar_name.to_s
      when Node::NotNode
        "not #{obj_to_perl obj.first}"
      when Node::CdeclNode
        cdecl_node_to_perl obj
      when Node::MasgnNode
        masgn_node_to_perl obj
      when Node::BlockNode
        block_node_to_perl obj
      when Node::WhileNode
        while_node_to_perl obj
      when Node::UntilNode
        until_node_to_perl obj
      when Node::KeywordBase
        obj.keyword
      when Node::DstrNode
        dstr_node_to_perl obj
      when Node::EvstrNode
        obj_to_perl obj.expression
      when Node::RescueNode
        rescue_node_to_perl obj
      when Node::ResbodyNode
        resbody_node_to_perl obj

      when Node::Base
        obj.arguments.map {|a| obj_to_perl a}.join("\n")
      when String
        obj.inspect
      when Regexp
        "qr#{obj.inspect}"
      else
        obj.to_s
      end
    end

    def semicolon_if_needed(node)
      node.parent.nil? || node.parent.is_a?(Node::BlockNode) || 
        (node.parent.is_a?(Node::IterNode) && node.parent.parent.is_a?(Node::BlockNode)) ? 
          ';' : ''
    end

    def call_node_to_perl(call_node)
      semicolon = semicolon_if_needed call_node
      if call_node.receiver && self.is_binary_operator(call_node.method_name)
        "#{obj_to_perl call_node.receiver} #{call_node.method_name} #{
          obj_to_perl call_node.arglist.first}#{semicolon}"
      elsif call_node.receiver.nil? && call_node.method_name == :puts
        %Q|say(#{obj_to_perl call_node.arglist.first})#{semicolon}|
      elsif call_node.receiver.nil? && call_node.method_name == :require
        mod = call_node.arglist.first.value.to_s
        mod = mod.split('/').map{|e| e.capitalize.gsub(/_([a-z])/){$1.upcase}}.join '::'
        "use #{mod}#{semicolon}"
      elsif call_node.receiver.nil? && call_node.method_name == :attr_accessor
        "__PACKAGE__->mk_accessors(qw(#{call_node.arglist.map{|lit| 
          lit.value.to_s}.join(' ')}))#{semicolon}"
      elsif call_node.method_name == :[]
        receiver = obj_to_perl call_node.receiver
        index = obj_to_perl call_node.arglist.first
        if receiver =~ /^@(.*)/
          "$#{$1}[#{index}]#{semicolon}"
        elsif index =~ /^\d+$/
          "#{receiver}->[#{index}]#{semicolon}"
        else
          "#{receiver}->{#{index}}#{semicolon}"
        end
      elsif call_node.method_name == :call # TODO: assume that the receiver is a block
        "#{obj_to_perl call_node.receiver}->(#{call_node.arglist.map {|a| obj_to_perl a}.join(', ')})#{semicolon}"
      elsif call_node.receiver && call_node.method_name == :size
        "(scalar @{#{obj_to_perl call_node.receiver}})#{semicolon}"
      elsif call_node.receiver && call_node.method_name == :empty?
        "(scalar @{#{obj_to_perl call_node.receiver}} == 0)#{semicolon}"
      elsif call_node.receiver && call_node.method_name == :to_arrayref # TODO: remove this
        "[#{obj_to_perl call_node.receiver}]#{semicolon}"
      elsif call_node.method_name == :map
        <<-EOS.gsub(/^ /, '')
          map {
            #{obj_to_perl call_node.next(2)}
          } #{obj_to_perl call_node.receiver}#{semicolon}
        EOS
      elsif call_node.receiver && [:find, :select].include?(call_node.method_name)
        "(grep { #{obj_to_perl call_node.next(2)} } @{#{obj_to_perl call_node.receiver}}) != 0#{semicolon}"
      elsif call_node.method_name == :is_a?
        arg = obj_to_perl call_node.arglist.first
        if arg == 'Array'
          "(ref #{obj_to_perl call_node.receiver} eq 'ARRAY')#{semicolon}"
        else
          "(ref #{obj_to_perl call_node.receiver} eq '#{arg}')#{semicolon}"
        end
      elsif is_unary_operator call_node.method_name
        method = call_node.method_name.to_s.sub /@$/, ''
        "#{method}(#{obj_to_perl call_node.receiver})#{semicolon}"
      else
        block = nil
        block_args = nil
        if call_node.parent.is_a?(Node::IterNode)
          block = call_node.parent.body
          block_args = call_node.next
          if call_node.method_name == :each
            var_name = block_args.arguments.first
            my = call_node.scope.variable_defined?(var_name) ? '' : 'my '
            return <<-EOS.gsub(/^ +/, '')
              for #{my}$#{var_name} (#{obj_to_perl call_node.receiver}) {
                #{obj_to_perl block}
              }
            EOS
          end
        end

        receiver = call_node.receiver ? "#{obj_to_perl call_node.receiver}->" : ''
        method = call_node.method_name.to_s
        if method =~ /^(.*)[!?]$/
          method = $1
        end
        args = call_node.arglist.map {|a| obj_to_perl a}.join(', ')
        if block
          args += ', ' unless args.empty?
          args += block_to_perl block, block_args
        elsif call_node.receiver.nil? && args.empty?
          if call_node.scope.variable_defined? method
            return "$#{method}"
          end
        end
        "#{receiver}#{method}(#{args})#{semicolon}"
      end
    end

    def is_unary_operator(op)
      op.to_s =~ /^(.*)@$/ || op.to_s =~ /^(!)$/
    end

    def is_binary_operator(op)
      %w(+ - * / < > <= >= == === <=> eq).include? op.to_s
    end

    def block_to_perl(block, args)
      asgn_args = if args
          args.arguments.map do |arg|
            "my $#{arg} = shift;"
          end.join "\n"
        else
          ''
        end
      <<-EOS.gsub(/^ +/, '')
        sub {
          #{asgn_args}
          #{obj_to_perl block}
        }
      EOS
    end

    def lasgn_node_to_perl(obj)
      semicolon = semicolon_if_needed obj
      if obj.scope.variable_defined? obj.var_name
        var_def = obj.scope.variable_definition obj.var_name
        sigil = var_def.type == :array ? '@' : '$'
        "#{sigil}#{obj.var_name} = #{obj_to_perl obj.value}#{semicolon}"
      else
        type = obj.value.is_a?(Node::ArrayNode) ? :array : :ref 
        obj.scope.define_variable obj.var_name, type
        sigil = type == :array ? '@' : '$'
        "my #{sigil}#{obj.var_name} = #{obj_to_perl obj.value}#{semicolon}"
      end
    end

    def defn_node_to_perl(obj)
      tmp_args = obj.method_args.arguments.dup

      klass = obj
      while (klass = klass.parent)
        break if klass.is_a? Node::ClassNode
      end
      tmp_args.unshift('self') if klass
      asgn_args = tmp_args.map do |arg|
        if arg.to_s =~ /^\*(.*)/
          obj.scope.define_variable $1, :array
          "my @#{$1} = @_;"
        elsif arg.to_s =~ /^\&(.*)/
          obj.scope.define_variable $1, :block
          "my $#{$1} = shift;"
        else
          obj.scope.define_variable arg
          "my $#{arg} = shift;"
        end
      end.join "\n"

      <<-EOS.gsub(/^ +/, '')
        sub #{obj.method_name} {
          #{asgn_args}
          #{obj_to_perl obj.body}
        }
      EOS
    end

    def class_node_to_perl(obj)
      fqcn = 
        if obj.class_name.is_a? Node::Colon3Node
          obj_to_perl obj.class_name
        elsif obj.class_name =~ /^::(.+)/
          $1
        else
          (obj.scope.all_modules.dup + [obj.class_name]).map {|e| obj_to_perl e}.join '::'
        end
      super_fqcn =
        if obj.super_class.nil?
          'Class::Accessor::Fast'
        elsif obj.super_class.is_a? Node::Colon3Node
          obj_to_perl obj.super_class
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

    def const_node_to_perl(obj)
      name = obj.const_name.to_s
      if obj.parent.is_a?(Node::CallNode) && obj.parent.receiver != obj
        # in arglist
        const_def = obj.scope.constant_definition name.to_sym
        sigil = const_def ? const_def.sigil : '$'
        "#{sigil}#{name}"
      else
        name
      end
    end

    def attrasgn_node_to_perl(obj)
      receiver = obj.receiver.var_name
      attr = obj.method_name.to_s.sub('=', '')
      if attr == '[]'
        index = obj_to_perl obj.arguments[2]
        val = obj_to_perl obj.arguments[3]
        "$#{receiver}->{#{index}} = #{val};"
      else
        val = obj_to_perl obj.value
        "$#{receiver}->#{attr}(#{val});"
      end
    end

    def lvar_node_to_perl(obj)
      var_def = obj.scope.variable_definition obj.var_name
      if var_def && var_def.type == :array
        "@#{obj.var_name}"
      elsif var_def && var_def.type == :block
        "$#{obj.var_name}"
      else
        "$#{obj.var_name}"
      end
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

    def block_node_to_perl(obj)
      if obj.arguments.size == 1 && obj.first.is_a?(Node::NilNode)
        ''
      else
        obj.arguments.map {|a| obj_to_perl a}.join("\n")
      end
    end

    def cdecl_node_to_perl(obj)
      name = obj_to_perl obj.const_name
      value = obj_to_perl obj.value
      type = obj.value.is_a?(Node::ArrayNode) ? :array : :ref
      const_def = obj.scope.define_constant name, type
      "use constant #{const_def.sigil}#{name} => #{value};"
    end

    def masgn_node_to_perl(obj)
      case obj.values
      when Node::SplatNode
        if obj.values.value.is_a? Node::LvarNode
          ret = ''
          values = obj.values.value.var_name
          obj.lasgns.arguments.each_with_index do |elm, i|
            obj.scope.define_variable elm.var_name
            ret += "my $#{elm.var_name} = $#{values}[#{i}];\n"
          end
          ret
        else
          vars = obj.lasgns.arguments.map do |a| 
            "$#{obj_to_perl a.var_name}"
          end
          "my (#{vars.join ', '}) = #{obj_to_perl obj.values};\n"
        end
      when Node::ArrayNode
        ret = ''
        values = obj.values.arguments
        obj.lasgns.arguments.each_with_index do |elm, i|
          obj.scope.define_variable elm.var_name
          ret += "my $#{elm.var_name} = #{obj_to_perl values[i]};\n"
        end
        ret
      else
        raise "must be a splat node or an array node: #{obj.values.class.name}"
      end
    end

    def while_node_to_perl(obj)
      <<-EOS.gsub /^ +/, ''
        while (#{obj_to_perl obj.condition}) {
          #{obj_to_perl obj.body}
        }
      EOS
    end

    def until_node_to_perl(obj)
      <<-EOS.gsub /^ +/, ''
        until (#{obj_to_perl obj.condition}) {
          #{obj_to_perl obj.body}
        }
      EOS
    end

    def dstr_node_to_perl(obj)
      ([obj.str.inspect] + obj.arguments[1..-1].map{|e| obj_to_perl e}).join ' . '
    end

    def rescue_node_to_perl(obj)
      rescue_bodies = obj.rescue_bodies.map{|e| obj_to_perl e}.join 'else '
      <<-EOS.gsub /^ +/, ''
        eval {
          #{obj_to_perl obj.body}
        };
        #{rescue_bodies}
      EOS
    end

    def resbody_node_to_perl(obj)
      rescue_var = obj.exception_name
      exception_class = obj.exception_class
      <<-EOS.gsub /^ +/, ''
        if ($@#{exception_class ? " && is_instance($@, \"#{exception_class}\")" : ''}) {#{
          rescue_var ? "\nmy $#{rescue_var} = $@;" : ''}
          #{obj_to_perl obj.body}
        }
      EOS
    end
  end
end

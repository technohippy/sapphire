require 'sapphire/generator'
require 'sapphire/node'

module Sapphire
  class PerlGenerator < Generator
    DEFAULT_PREFIX = "use strict;\nuse warnings;\n"
    DEFAULT_SUFFIX = "\n1;"

    def initialize(prefix=DEFAULT_PREFIX, suffix=DEFAULT_SUFFIX)
      super
    end

    def generate_body
      obj_to_perl @root_node
    end

    def obj_to_perl(obj)
      case obj
      when Node::AndNode
        "#{obj_to_perl obj.left} and #{obj_to_perl obj.right}"
      when Node::ArgsNode
        obj.arguments.map {|a| obj_to_perl a}.join(', ')
      when Node::ArrayNode
        "(#{obj.arguments.map {|a| obj_to_perl a}.join(', ')})"
      when Node::AttrasgnNode
        attrasgn_node_to_perl obj
      when Node::BlockNode
        block_node_to_perl obj
      when Node::CallNode
        call_node_to_perl obj
      when Node::CdeclNode
        cdecl_node_to_perl obj
      when Node::ClassNode
        class_node_to_perl obj
      when Node::ConstNode
        const_node_to_perl obj
      when Node::Colon2Node
        "#{obj_to_perl obj.head}::#{obj_to_perl obj.tail}"
      when Node::Colon3Node
        obj_to_perl obj.tail
      when Node::CvarNode
        cvar_node_to_perl obj
      when Node::CvdeclNode
        cvdecl_node_to_perl obj
      when Node::DefnNode
        defn_node_to_perl obj
      when Node::DstrNode
        dstr_node_to_perl obj
      when Node::EvstrNode
        obj_to_perl obj.expression
      when Node::GvarNode
        gvar_node_to_perl obj
      when Node::HashNode
        hash_node_to_perl obj
      when Node::IfNode
        if_node_to_perl obj
      when Node::IterNode
        obj_to_perl obj.first
      when Node::LasgnNode
        lasgn_node_to_perl obj
      when Node::LitNode
        obj_to_perl obj.value
      when Node::LvarNode
        lvar_node_to_perl obj
      when Node::MasgnNode
        masgn_node_to_perl obj
      when Node::Match3Node
        "#{obj_to_perl obj.target} =~ #{obj_to_perl obj.regexp}"
      when Node::ModuleNode
        obj_to_perl obj.body
      when Node::NotNode
        "not #{obj_to_perl obj.first}"
      when Node::OrNode
        "#{obj_to_perl obj.left} or #{obj_to_perl obj.right}"
      when Node::ResbodyNode
        resbody_node_to_perl obj
      when Node::RescueNode
        rescue_node_to_perl obj
      when Node::ReturnNode
        "return #{obj_to_perl obj.value};"
      when Node::StrNode
        obj.value.inspect
      when Node::UntilNode
        until_node_to_perl obj
      when Node::WhileNode
        while_node_to_perl obj
      when Node::XstrNode
        value = obj.value.to_s
        value.index("\n") ? value.strip : value

      when Node::KeywordBase
        obj.keyword
      when Node::Base
        obj.arguments.map {|a| obj_to_perl a}.join("\n")
      when Symbol # inline perl
        obj.to_s.index("\n") ? obj.to_s.strip : obj.to_s
      when String
        obj.inspect
      when Regexp
        "qr#{obj.inspect}"
      else
        obj.to_s
      end
    end

    def attrasgn_node_to_perl(obj)
      receiver = 
        if obj.receiver.is_a?(Node::LitNode) && obj.receiver.value.is_a?(Symbol)
          obj.receiver.value.to_s
        else
          "$#{obj.receiver.var_name}"
        end
      attr = obj.method_name.to_s.sub('=', '')
      if attr == '[]'
        index = obj_to_perl obj.arguments[2]
        val = obj_to_perl obj.arguments[3]
        "#{receiver}->{#{index}} = #{val};"
      else
        val = obj_to_perl obj.value
        "#{receiver}->#{attr}(#{val});"
      end
    end

    def block_node_to_perl(obj)
      if obj.arguments.size == 1 && obj.first.is_a?(Node::NilNode)
        ''
      else
        obj.arguments.map {|a| obj_to_perl a}.join("\n")
      end
    end

    # TODO: need refactoring
    def call_node_to_perl(obj)
      if obj.receiver && self.is_binary_operator(obj.method_name)
        receiver = obj_to_perl obj.receiver
        arg = obj_to_perl obj.arglist.first
        method_name = 
          if obj.method_name == :== && (receiver =~ /\".*\"/ || arg =~ /\".*\"/)
            :eq
          elsif obj.method_name == :'!=' && (receiver =~ /\".*\"/ || arg =~ /\".*\"/)
            :ne
          else
            obj.method_name
          end
        "#{receiver} #{method_name} #{arg}"
      elsif obj.receiver && obj.method_name == :to_i
        "(0 + #{obj_to_perl obj.receiver})"
      elsif obj.receiver.nil? && obj.method_name == :puts
        %Q|print(#{obj_to_perl obj.arglist.first} . "\\n")|
      elsif obj.receiver.nil? && obj.method_name == :require
        mod = obj.arglist.first.value.to_s
        mod = mod.split('/').map{|e| e.capitalize.gsub(/_([a-z])/){$1.upcase}}.join '::'
        imports = if obj.arglist[1]
            " qw(#{obj.arglist[1].arguments.map{|str| str.value.to_s}.join ' '})"
          else
            ''
          end
        "use #{mod}#{imports}"
      elsif obj.receiver.nil? && obj.method_name == :attr_accessor
        "__PACKAGE__->mk_accessors(qw(#{obj.arglist.map{|lit| 
          lit.value.to_s}.join(' ')}))"
      elsif obj.receiver.is_a?(Node::SelfNode) && 
        obj.parent.is_a?(Node::BlockNode) && 
        obj.parent.parent.is_a?(Node::ClassNode)
        # TODO
        "__PACKAGE__->#{obj.method_name}(#{obj.arglist.map {|a| obj_to_perl a}.join(', ')})"
      elsif obj.receiver.is_a?(Node::SelfNode) &&
        obj.method_name == :class
        "__PACKAGE__"
      elsif obj.method_name == :[]
        receiver = obj_to_perl obj.receiver
        index = obj_to_perl obj.arglist.first
        if receiver =~ /^@(.*)/
          "$#{$1}[#{index}]"
        elsif index =~ /^\d+$/
          "#{receiver}->[#{index}]"
        else
          "#{receiver}->{#{index}}"
        end
      elsif obj.method_name == :call && 
        obj.receiver && 
        obj.receiver.is_a?(Node::LvarNode) && 
        obj.scope.variable_definition(obj.receiver.var_name) && 
        obj.scope.variable_definition(obj.receiver.var_name).kind == :block # TODO
        "#{obj_to_perl obj.receiver}->(#{obj.arglist.map {|a| obj_to_perl a}.join(', ')})"
      elsif obj.receiver && obj.method_name == :size
        receiver = obj_to_perl obj.receiver
        receiver = "@{#{receiver}}" unless receiver =~ /^@/
        "(scalar #{receiver})"
      elsif obj.receiver && obj.method_name == :empty?
        receiver = obj_to_perl obj.receiver
        receiver = "@{#{receiver}}" unless receiver =~ /^@/
        "(scalar #{receiver} == 0)"
      elsif obj.receiver && obj.method_name == :push
        receiver = obj_to_perl obj.receiver
        receiver = "@{#{receiver}}" unless receiver =~ /^@/
        arg = obj_to_perl obj.arglist.first
        arg = "@{#{arg}}" unless arg =~ /^@/
        "push(#{receiver}, #{arg})"
      elsif obj.receiver && obj.method_name == :pop
        receiver = obj_to_perl obj.receiver
        receiver = "@{#{receiver}}" unless receiver =~ /^@/
        "pop(#{receiver})"
      elsif obj.receiver && obj.method_name == :shift
        receiver = obj_to_perl obj.receiver
        receiver = "@{#{receiver}}" unless receiver =~ /^@/
        "shift(#{receiver})"
      elsif obj.receiver && obj.method_name == :to_ref # TODO
        "${#{obj_to_perl obj.receiver}}"
      elsif obj.receiver && obj.method_name == :to_arrayref # TODO
        "[#{obj_to_perl obj.receiver}]"
      elsif obj.receiver && obj.method_name == :to_hash # TODO
        obj_to_perl obj.receiver
      elsif obj.receiver && [:find, :select].include?(obj.method_name)
        "(grep { #{obj_to_perl obj.next(2)} } @{#{obj_to_perl obj.receiver}}) != 0"
      elsif obj.method_name == :is_a?
        arg = obj_to_perl obj.arglist.first
        if arg == 'Array'
          "(ref #{obj_to_perl obj.receiver} eq 'ARRAY')"
        else
          "(ref #{obj_to_perl obj.receiver} eq '#{arg}')"
        end
      elsif is_unary_operator obj.method_name
        method = obj.method_name.to_s.sub /@$/, ''
        "#{method}(#{obj_to_perl obj.receiver})"
      else
        block = nil
        block_args = nil
        if obj.parent.is_a?(Node::IterNode)
          block = obj.parent.body
          block_args = obj.next
          if obj.method_name == :each
            if block_args.arguments.size == 2 # hash
              key_name = block_args.arguments[0]
              val_name = block_args.arguments[1]
              return <<-EOS.gsub(/^ +/, '')
                while (my ($#{key_name}, $#{val_name}) = each(#{obj_to_perl obj.receiver})) {
                  #{obj_to_perl block}
                }
              EOS
            else # array
              var_name = block_args.arguments.first
              my = obj.scope.variable_defined?(var_name) ? '' : 'my '
              return <<-EOS.gsub(/^ +/, '')
                for #{my}$#{var_name} (#{obj_to_perl obj.receiver}) {
                  #{obj_to_perl block}
                }
              EOS
            end
          elsif obj.method_name == :map
            receiver = obj_to_perl obj.receiver
            if receiver =~ /^\$/
              receiver = "@{#{receiver}}" # TODO
            end
            return <<-EOS.gsub(/^ +/, '').strip
              map {
                #{obj_to_perl block}
              } #{receiver}
            EOS

          elsif obj.method_name == :lambda
            return block_to_perl(block, block_args) + semicolon_if_needed(obj.parent)
          end
        end

        receiver = obj.receiver ? "#{obj_to_perl obj.receiver}->" : ''
        method = obj.method_name.to_s
        if method =~ /^(.*)[!?]$/
          method = $1
        end
        args = obj.arglist.map {|a| obj_to_perl a}.join(', ')
        if block
          args += ', ' unless args.empty?
          args += block_to_perl block, block_args
        end
        "#{receiver}#{method}(#{args})"
      end + semicolon_if_needed(obj)
    end

    def cdecl_node_to_perl(obj)
      name = obj_to_perl obj.const_name
      value = obj_to_perl obj.value
      kind = obj.value.is_a?(Node::ArrayNode) ? :array : :ref
      const_def = obj.scope.define_constant name, kind
      "use constant #{const_def.sigil}#{name} => #{value};"
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
          nil
        elsif obj.super_class.is_a? Node::Colon3Node
          obj_to_perl obj.super_class
        elsif obj.super_class =~ /^::(.+)/
          $1
        else
          (obj.scope.all_modules.dup + [obj.super_class]).map {|e| obj_to_perl e}.join '::'
        end
      <<-EOS.gsub(/^ +/, '')
        {
          package #{fqcn};#{super_fqcn ? "\nuse base '#{super_fqcn}';" : ''}
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

    def cvar_node_to_perl(obj)
      var_def = obj.scope.variable_definition obj.name
      "#{var_def.sigil}#{obj.cvar_name}"
    end

    def cvdecl_node_to_perl(obj)
      obj.scope.define_variable obj.name, obj.value.kind
      name = obj.cvar_name
      value = obj_to_perl obj.value
      sigil = obj.value.is_a?(Node::ArrayNode) ? '@' : 
        obj.value.is_a?(Node::HashNode) ? '%' : '$'
      "our #{sigil}#{name} = #{value};"
    end

    def defn_node_to_perl(obj)
      tmp_args = obj.method_args.arguments.dup

      klass = obj
      while (klass = klass.parent)
        break if klass.is_a? Node::ClassNode
      end
      if klass
        if tmp_args.first == :__no_self__
          tmp_args.shift
        else
          tmp_args.unshift('self')
        end
      end
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

    def dstr_node_to_perl(obj)
      ([obj.str.inspect] + obj.arguments[1..-1].map{|e| obj_to_perl e}).join ' . '
    end

    def gvar_node_to_perl(obj)
      obj.gvar_name == :$! ? '$@' : obj.gvar_name.to_s
    end

    def hash_node_to_perl(obj)
      "{#{
        Hash[*obj.arguments].to_a.map do |k, v|
          "#{obj_to_perl k} => #{obj_to_perl v}"
        end.join ', '
      }}"
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

    def lasgn_node_to_perl(obj)
      semicolon = semicolon_if_needed obj
      sigil = obj.value.kind == :array ? '@' : obj.value.kind == :hash ? '%' : '$'
      if obj.scope.variable_defined? obj.var_name
        "#{sigil}#{obj.var_name} = #{obj_to_perl obj.value}#{semicolon}"
      else
        obj.scope.define_variable obj.var_name, obj.value.kind
        "my #{sigil}#{obj.var_name} = #{obj_to_perl obj.value}#{semicolon}"
      end
    end

    def lvar_node_to_perl(obj)
      var_def = obj.scope.variable_definition obj.var_name
      if var_def && var_def.kind == :array
        "@#{obj.var_name}"
      elsif var_def && var_def.kind == :hash
        "%#{obj.var_name}"
      elsif var_def && var_def.kind == :block
        "$#{obj.var_name}"
      else
        "$#{obj.var_name}"
      end
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
      when Node::ToAryNode
        vars = obj.lasgns.arguments.map do |a| 
          "$#{obj_to_perl a.var_name}"
        end
        "my (#{vars.join ', '}) = #{obj_to_perl obj.values};\n"
      else
        raise "must be a splat node or an array node: #{obj.values.class.name}"
      end
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

    def rescue_node_to_perl(obj)
      rescue_bodies = obj.rescue_bodies.map{|e| obj_to_perl e}.join 'else '
      <<-EOS.gsub /^ +/, ''
        eval {
          #{obj_to_perl obj.body}
        };
        #{rescue_bodies}
      EOS
    end

    def until_node_to_perl(obj)
      <<-EOS.gsub /^ +/, ''
        until (#{obj_to_perl obj.condition}) {
          #{obj_to_perl obj.body}
        }
      EOS
    end

    def while_node_to_perl(obj)
      <<-EOS.gsub /^ +/, ''
        while (#{obj_to_perl obj.condition}) {
          #{obj_to_perl obj.body}
        }
      EOS
    end

    def semicolon_if_needed(node)
      node.parent.nil? || node.parent.is_a?(Node::BlockNode) || 
        (node.parent.is_a?(Node::IterNode) && node.parent.parent.is_a?(Node::BlockNode)) ? 
          ';' : ''
    end

    def is_unary_operator(op)
      %w(+@ -@ !).include? op.to_s
    end

    def is_binary_operator(op)
      %w(+ - * / % ** < > <= >= == != === <=> | ^ << >> && || 
        .. and or eq ne cmp lt gt le ge).include? op.to_s
    end

    def block_to_perl(block, args)
      asgn_args = if args && args != 0
          args[0] = :self if args.first == :__self__ # TODO
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
  end
end

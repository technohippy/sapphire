require 'sapphire/parser'

module Sapphire
  class Converter
    BARE_TYPE = 's'

    def convert(string, type)
      if type == BARE_TYPE
        require 'pp'
        pp RubyParser.new.parse(string) # TODO: 文字列を返すようにいずれ変更
      else
        require type
        class_name = "::#{type.split('/').map{|e| e.capitalize.gsub(/_([a-z])/){$1.upcase}}.join '::'}"
        generator = eval(class_name).new(Parser.new.parse string)
        generator.generate
      end
    end

    def convert_file(file, type)
      convert file.read, type
    end
  end
end

require 'sapphire/parser'

module Sapphire
  class Converter
    def convert(string, type)
      require type
      class_name = type.split('/').map{|e| e.capitalize.gsub(/_([a-z])/){$1.upcase}}.join '::'
      generator = eval(class_name).new(Parser.new.parse string)
      generator.generate
    end

    def convert_file(file, type)
      convert file.read, type
    end
  end
end

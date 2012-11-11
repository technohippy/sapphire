require 'sapphire/parser'
require 'sapphire/perl_generator'
require 'mixi_perl_generator'

module Sapphire
  class Converter
    def convert(string)
      generator = PerlGenerator.new(Parser.new.parse string)
      generator.generate
    end

    def convert_file(file)
      convert file.read
    end
  end
end

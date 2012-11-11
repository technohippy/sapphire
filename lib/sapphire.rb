require 'sapphire/converter'

module Sapphire
  VERSION = '0.0.1'
  DEFAULT_GENERATOR = 'sapphire/perl_generator'

  def self.convert(string_or_file, type=nil)
    type ||= DEFAULT_GENERATOR
    if string_or_file.is_a? File
      self.convert_file string_or_file, type
    else
      self.convert string_or_file, type
    end
  end

  def self.convert_string(string, type=nil)
    type ||= DEFAULT_GENERATOR
    Converter.new.convert string, type
  end

  def self.convert_file(string_or_file, type=nil)
    type ||= DEFAULT_GENERATOR
    if string_or_file.is_a? File or string_or_file.is_a? ARGF.class
      Converter.new.convert_file string_or_file, type
    else
      string_or_file.open do |file|
        Converter.new.convert_file file, type
      end
    end
  end
end

require 'sapphire/converter'

module Sapphire
  VERSION = '0.0.1'

  def self.convert(string_or_file)
    if string_or_file.is_a? File
      self.convert_file string_or_file
    else
      self.convert string_or_file
    end
  end

  def self.convert_string(string)
    Converter.new.convert string
  end

  def self.convert_file(string_or_file)
    if string_or_file.is_a? File or string_or_file.is_a? ARGF.class
      Converter.new.convert_file string_or_file
    else
      string_or_file.open do |file|
        Converter.new.convert_file file
      end
    end
  end
end

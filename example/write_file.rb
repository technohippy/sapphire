# http://learn.perl.org/examples/read_write_file.html
require 'path/class'
require 'autodie'

dir = dir '/tmp'
file = dir.file 'file.txt'
file_handle = file.openw
list = %w(a list of lines)
list.each do |line|
  file_handle.print "#{line}\n"
end

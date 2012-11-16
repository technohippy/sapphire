# http://learn.perl.org/examples/read_write_file.html
require 'path/class'
require 'autodie'

dir = dir '/tmp'
file = dir.file 'file.txt'
content = file.slurp
file_handle = file.openr
while line = file_handle.getline
  print line;
end

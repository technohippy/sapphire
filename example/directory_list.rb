# http://learn.perl.org/examples/directory_list.html
require 'path/class'

dir = dir 'lib', 'sapphire'

while file = dir.next
  next if file.is_dir?
  puts file.stringify
end

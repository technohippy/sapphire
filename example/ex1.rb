[1, 2, 3, 4].each do |a|
  puts a
end

def iterate(a, b, c)
  [a, b, c].each do |d|
    puts d
  end
end

iterate 5, 6, 7

class Foo
  attr_accessor :name

  def bar
    puts 'Hello, '
  end
end

adam = Foo.new
adam = Foo.new
adam.name = 'Adam Beynon'
adam.bar
puts adam.name

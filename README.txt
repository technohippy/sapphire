= sapphire

* Sapphire (http://github.com/technohippy/sapphire)

== DESCRIPTION:

Sapphire is a ruby to perl compiler. I'm developing this just for fun.

== FEATURES/PROBLEMS:

* FOR LIGHT PURPOSES ONLY.

== SYNOPSIS:

  $ cat example/ex0.rb 
  [1, 2, 3, 4].each do |a|
    puts a
  end

  class Foo
    attr_accessor :name
  end
  
  yasushi = Foo.new
  yasushi.name = 'ANDO Yasushi'
  puts yasushi.name

  $ ruby -Ilib bin/sapphire example/ex0.rb 
  use strict;
  use warnings;
  
  for $a ( 1, 2, 3, 4 ) {
      print( $a . "\n" );
  }
  
  {
  
      package Foo;
      use base 'Class::Accessor::Fast';
      __PACKAGE__->mk_accessors(qw(name));
  }
  
  my $yasushi = Foo->new();
  $yasushi->name("ANDO Yasushi");
  print( $yasushi->name() . "\n" );
  1;

  $ ruby -Ilib bin/sapphire example/ex0.rb | perl
  1
  2
  3
  4
  ANDO Yasushi

== REQUIREMENTS:

* ruby_parser
* Perl::Tidy
* Class::Accessor::Fast (to execute a generated perl code)

== INSTALL:

* sudo gem install sapphire

== LICENSE:

(The MIT License)

Copyright (c) 2012 ANDO Yasushi

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

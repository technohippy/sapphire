# http://learn.perl.org/examples/static_server.html
require 'plack/app/directory'

app = Plack::App::Directory.new('root' => '/example').to_app

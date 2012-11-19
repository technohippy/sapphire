# http://learn.perl.org/examples/dns.html
require 'net/d_n_s/resolver'

hostname = 'perl.org'
res = Net::DNS::Resolver.new 'nameservers', %w(8.8.8.8).to_arrayref
query = res.search hostname

if query
  query.answer.each do |rr|
    next unless rr.type.eq 'A'
    puts "Found an A record: #{rr.address}"
  end
end

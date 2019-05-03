#!/opt/chef/embedded/bin/ruby

# Usage: ./a2auth.rb [list [tokens | policies] | trim | trimtok | purge]
#     list - list tokens or policies or both
#     trim - remove duplicate policies
#     trimtok - remove policies for non-existent tokens
#     purge - remove all tokens
#     add '<json>' - add a policy
#     dump [policies | tokens] - dump JSON of policies and tokens
#     lockdown - remove all policies and replace with a default readall

require 'json'
require 'net/http'
require 'uri'
require 'openssl'

# for i in 0 ... ARGV.length
#    puts "#{i} #{ARGV[i]}"
# end

require 'optparse'

options = {}
options[:authtoken] = ''
options[:url] = ''
OptionParser.new do |opts|
  opts.banner = 'Usage: a2auth.rb [options]'

  opts.on('-u', '--url URL', 'API auth base url') do |ourl|
    options[:url] = ourl
  end
  opts.on('-t', '--token TOKEN', 'Admin token') do |tok|
    options[:authtoken] = tok
  end
  opts.on('-r', '--[no-]raw', 'Raw JSON output') do |raw|
    options[:raw] = raw
  end
end.parse!

# p options
# p ARGV

# curl -k -H "api-token: $TOK" -H "Content-Type: application/json" -d '{"active":"false"}' https://default-wbc-centos-7.vagrantup.com/api/v0/auth/tokens/$TOK
# curl -k -H "api-token: $TOK" -H "Content-Type: application/json" -d '{"active": "false"}' https://localhost/api/v0/auth/tokens/$TOK

type = 'policies'

url = options[:url]
url = 'https://localhost/api/v0/auth' if options[:url] == ''

IAMVER = `chef-automate iam version 2>&1 | grep "IAM v2.0"`
IAMV2 = !IAMVER.empty?
url = 'https://localhost/apis/iam/v2beta' if IAMV2

tok = options[:authtoken]
tok = `sudo /bin/chef-automate admin-token 2>/dev/null` if tok == '' && ! IAMV2
# try IAMv2 command form if the above fails
tok = `sudo /bin/chef-automate iam token create a2auth --admin` if tok == ''
authtoken = tok.chomp

checkhash = {}

def valid_json?(string)
  !!JSON.parse(string)
rescue JSON::ParserError
  false
end

def delete_object(authtok, url)
  # begin
  uri = URI.parse(url)
  request = Net::HTTP::Delete.new(uri)
  request.content_type = 'application/json'
  request['Api-Token'] = authtok

  req_options = {
    use_ssl: uri.scheme == 'https',
    verify_mode: OpenSSL::SSL::VERIFY_NONE,
  }
  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end
  puts "FAILURE #{response.code} DELETING #{url}" if response.code != '200'
  # end
end

def add_object(authtoken, url, jdata)
  uri = URI.parse(url)
  # request = Net::HTTP::Put.new(uri)
  request = Net::HTTP::Post.new(uri)
  request.content_type = 'application/json'
  request['Api-Token'] = authtoken
  request.body = jdata
  # puts "ADDING #{request.body}"
  req_options = {
    use_ssl: uri.scheme == 'https',
    verify_mode: OpenSSL::SSL::VERIFY_NONE,
  }
  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end
  # puts response.body
  puts "FAILURE #{response.code} ADDING OBJECT #{jdata} to #{url}" if response.code != '200'
  # system "curl -q -k -X POST -H \"api-token: #{authtoken}\" -H \"Content-Type: application/json\" -d '#{jdata}' #{url} > /dev/null 2>&1"
end

tokenhash = {}
tokidhash = {}
tokdata = {}
polsubhash = {}
poldata = {}

at_exit do # cleanup
  exit unless options[:authtoken] == ''
  # clean up temporary admin authtoken

  # token id for the token value
  admintokenid = tokenhash[authtoken]
  # policy id for this authtoken id in 'subjects' form
  # puts "deleting policy #{policytokenid} and token #{admintokenid}"
  delete_object(authtoken, "#{url}/tokens/#{admintokenid}")
  # can't delete the policy if we've deleted the admin token!
  # policytokenid = polsubhash['["token:' + admintokenid + '"]']
  # delete_object(authtoken,"#{url}/policies/#{policytokenid}")
end

# build hash of tokens

uri = URI.parse("#{url}/tokens")
request = Net::HTTP::Get.new(uri)
request.content_type = 'application/json'
request['Api-Token'] = authtoken
req_options = {
  use_ssl: uri.scheme == 'https',
  verify_mode: OpenSSL::SSL::VERIFY_NONE,
}
response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
  http.request(request)
end
# puts response.code
if response.code != '200'
  puts 'ERROR: admin token failed'
  exit 1
end

# puts response.code
# puts response.body
data = JSON.parse(response.body)
data['tokens'].each do |child|
  tokidhash['["token:' + child['id'] + '"]'] = child['value']
  # puts tokidhash['["token:' + child['id'] + '"]']
  tokenhash[child['value']] = child['id']
  tokdata[child['id']] = child
end

# build hash of policies by subject (as string)
uri = URI.parse("#{url}/policies")
request = Net::HTTP::Get.new(uri)
request.content_type = 'application/json'
request['Api-Token'] = authtoken
req_options = {
  use_ssl: uri.scheme == 'https',
  verify_mode: OpenSSL::SSL::VERIFY_NONE,
}
response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
  http.request(request)
end

# puts response.code
# puts response.body
data = JSON.parse(response.body)
data['policies'].each do |child|
  subjects = child['subjects'].to_s
  if subjects == '[]'
    # delete null subject policies with prejudice
    delete_object(authtoken, "#{url}/policies/#{child['id']}")
  else
    polsubhash[subjects] = child['id']
    puts polsubhash[subjects] + ' = ' + subjects
    poldata[child['id']] = child
  end
end

if ARGV[0] == 'trim'

  type = 'policies'
  # list resource type
  poldata.each do |pol, pdata|
    # puts pol
    # puts '|' + data['resource'] + '|' + data['effect'] + '|' + data['subjects'].to_s + '|' + data['action'].to_s
    polstring = '|' + pdata['resource'] + '|' + pdata['effect'] + '|' + pdata['subjects'].to_s + '|' + pdata['action'].to_s
    if checkhash.key?(polstring)
      puts "Deleting duplicate policy #{pol} (#{polstring})" unless pdata['subjects'].to_s == '[]'
      delete_object(authtoken, "#{url}/#{type}/#{pol}")
    else
      # add policy values to hash
      checkhash[polstring] = pol
    end
  end

elsif ARGV[0] == 'add'

  otype = ARGV[1]
  if otype != 'token' && otype != 'policy'
    puts "ERROR: object type #{otype} is not valid"
    exit(1)
  end

  if ARGV[2].nil?
    puts 'ERROR: missing JSON data'
    exit(1)
  end
  odata = ARGV[2]

  unless valid_json?(odata)
    puts 'ERROR: invalid JSON data'
    exit(1)
  end

  utype = 'policies'
  utype = 'tokens' if otype == 'token'

  add_object(authtoken, "#{url}/#{utype}", odata)

elsif ARGV[0] == 'delid'

  if ARGV[1].nil?
    puts 'ERROR: missing object id'
    exit(1)
  end
  objid = ARGV[1]
  if poldata[objid].nil? && tokdata[objid].nil?
    puts "ERROR: object id '#{objid}' does not exist"
    exit(1)
  end
  delete_object(authtoken, "#{url}/tokens/#{objid}") unless tokdata[objid].nil?
  delete_object(authtoken, "#{url}/policies/#{objid}") unless poldata[objid].nil?

elsif ARGV[0] == 'delete'

  if ARGV[1].nil?
    puts 'ERROR: missing policy json'
    exit(1)
  end
  polj = JSON.parse(ARGV[1])
  polstring = polj['subjects'].to_s + '|' + polj['action'] + '|' + polj['resource'] + '|' + polj['effect']
  # puts polstring
  data['policies'].each do |child|
    polcmp = child['subjects'].to_s + '|' + child['action'] + '|' + child['resource'] + '|' + child['effect']
    # delete any policies that match the requested json
    delete_object(authtoken, "#{url}/policies/#{child['id']}") if polstring == polcmp
  end

elsif ARGV[0] == 'trimtok'

  # delete unused token and empty subject policies

  poldata.each do |pol, pdata|
    subjects = pdata['subjects'].to_s
    next unless subjects[/token:[0-9a-f]/] || subjects == '[]'
    # puts pol + '|' + subjects
    if tokidhash[subjects].nil?
      delete_object(authtoken, "#{url}/policies/#{pol}")
    end
  end

elsif ARGV[0] == 'purge' # all tokens

  if ARGV[1].nil? || ARGV[1] == 'tokens'
    puts 'TOKENS' if ARGV[1].nil?
    tokdata.each do |ttok, _data|
      # puts tok.to_s + ' - ' + data.to_s
      # don't delete the current admin authtoken
      next if ttok == tokenhash[authtoken]
      puts "Deleting #{ttok}"
      delete_object(authtoken, "#{url}/tokens/#{ttok}")
    end
  end

# unwise to delete policies
#  if ARGV[1].nil? || ARGV[1] == 'policies'
#    puts "POLICIES" unless !ARGV[1].nil?
#    poldata.each do |pol,data|
#      # puts pol.to_s + ' - ' + data.to_s
#      puts data['subjects'].to_s + '|' + data['action'] + '|' + data['resource'] + '|' + data['effect']
#    end
#  end

elsif ARGV[0] == 'lockdown'

  poldata.each do |pol, _data|
    # puts pol.to_s + ' - ' + data.to_s
    # don't delete the current admin authtoken
    next if pol == polsubhash['["token:' + tokenhash[authtoken] + '"]']
    puts "Deleting #{pol}"
    delete_object(authtoken, "#{url}/policies/#{pol}")
  end
  # restore read all
  readall = '{ "action": "read", "resource": "*", "subjects": ["user:*"] }'
  add_object(authtoken, "#{url}/policies", readall)

elsif ARGV[0] == 'dump'

  polid = ARGV[2].nil? ? '' : '/' + ARGV[2]
  if ARGV[1].nil? || ARGV[1] == 'policies'
    uri = URI.parse("#{url}/policies#{polid}")
    request = Net::HTTP::Get.new(uri)
    request.content_type = 'application/json'
    request['Api-Token'] = authtoken
    req_options = {
      use_ssl: uri.scheme == 'https',
      verify_mode: OpenSSL::SSL::VERIFY_NONE,
    }
    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end
    puts response.body if options[:raw]
    puts JSON.pretty_generate(JSON.parse(response.body)) unless options[:raw]
  end
  if ARGV[1].nil? || ARGV[1] == 'tokens'
    uri = URI.parse("#{url}/tokens#{polid}")
    request = Net::HTTP::Get.new(uri)
    request.content_type = 'application/json'
    request['Api-Token'] = authtoken
    req_options = {
      use_ssl: uri.scheme == 'https',
      verify_mode: OpenSSL::SSL::VERIFY_NONE,
    }
    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end
    puts response.body if options[:raw]
    puts JSON.pretty_generate(JSON.parse(response.body)) unless options[:raw]
  end

else # list items

  if ARGV[1].nil? || ARGV[1] == 'tokens'
    puts 'TOKENS' if ARGV[1].nil?
    tokdata.each do |ttok, tdata|
      # puts ttok.to_s + ' - ' + tdata.to_s
      # don't list the current admin authtoken
      next if ttok == tokenhash[authtoken]
      puts tdata['id'] + '|' + tdata['value'] + '|' + tdata['active'].to_s
    end
  end

  if ARGV[1].nil? || ARGV[1] == 'policies'
    puts 'POLICIES' if ARGV[1].nil?
    poldata.each do |pol, pdata|
      # puts pol.to_s + ' - ' + pdata.to_s
      # don't list the current admin token policy
      next if pol == polsubhash['["token:' + tokenhash[authtoken] + '"]'] || pdata['subjects'].to_s == '[]'
      puts pol.to_s + '|' + pdata['subjects'].to_s + '|' + pdata['action'].to_s + '|' + pdata['resource'].to_s + '|' + pdata['effect'].to_s unless IAMV2

      stmts = pdata['statements'][0] if IAMV2
      puts pol.to_s + '|' + pdata['members'].to_s + '|' + stmts['actions'].to_s + '|' + stmts['resources'].to_s + '|' + stmts['effect'].to_s if IAMV2
    end
  end

end

exit


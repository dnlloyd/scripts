require 'net/http'
require 'uri'
require 'json'
require 'openssl'

token = ARGV[0]

uri = URI.parse('https://api.github.com/user/repository_invitations')

request = Net::HTTP::Get.new(uri)
request["Accept"] = "application/vnd.github.v3+json"
request["Authorization"] = "token #{token}"

req_options = {
  use_ssl: uri.scheme == "https",
}

response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
  http.request(request)
end

result = JSON.parse(response.body) unless response.body.nil?

result.each do | invite |
  puts "Accepting invite for: #{invite['repository']['name']}"
  uri = URI.parse("https://api.github.com/user/repository_invitations/#{invite['id']}")

  request = Net::HTTP::Patch.new(uri)
  request["Accept"] = "application/vnd.github.v3+json"
  request["Authorization"] = "token #{token}"

  req_options = {
    use_ssl: uri.scheme == "https",
  }

  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end

  puts response
  puts ''
end

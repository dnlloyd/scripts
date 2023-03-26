require 'net/http'
require 'uri'
require 'json'
require 'openssl'
require 'colorize'

# Usage: ruby github_user_audit.rb <username>

# requires credentials file located at: $HOME/.github/credentials.json
# Example credentials file:
# {
#   "svcAcct": "<TOKEN>",
#   "dnlloyd": "<TOKEN>"
# }

# Requires a separate account (token) to query private repos
# This account must have push privs to the private repo

$base_url = 'https://github.com'

private_repos = ['dnlloyd/My-Dynamic-DNS']
other_repos = ['dnlloyd/cookbook-multipath']

credentials_file = File.read("#{ENV['HOME']}/.github/credentials.json")
credentials= JSON.parse(credentials_file)
token = credentials[ARGV[0]]  # svcAcct
private_repo_token = credentials['dnlloyd'] # This account must have privs to push to the private repo

get_user_org_info = true

@loglevel = 'info'

def api_call_with_auth(api, resource_path, query, token)
  url = [$base_url, 'api/v3', api, resource_path].join('/').chomp("/")
  url = url + query if query != ''

  # puts '-------------'
  # puts "URL: #{url}"
  # puts '-------------'

  uri = URI.parse(url)

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

  return response, result
end

def get_user(token)
  response, result = api_call_with_auth('user', '', '', token)
  username = result['login']
end

def get_user_orgs(username, token)
  response, result = api_call_with_auth('users', "#{username}/orgs", '', token)

  orgs = []
  result.each do | org |
    orgs.push(org['login'])
  end

  orgs
end

# Note: Does not return privaye repositories
def get_user_repos(username, token)
  response, result = api_call_with_auth('users', "#{username}/repos", '?type=all', token)
  
  repos = []
  result.each do | repo |
    repos.push([repo['owner']['login'], repo['name']].join('/'))
  end

  repos
end

def get_repo(repo, token)
  response, result = api_call_with_auth( 'repos', repo, '', token)

  puts '------------- result -------------'
  puts result

  result
end

def get_repo_collaborators(repo, user, token)
  collaborators = {}
  
  response, result = api_call_with_auth( 'repos', "#{repo}/collaborators/", '?per_page=100', token)

  member = false
  if response.code == '200'
    result.each do |collaborator|
      if collaborator['login'] == user
        member = true
        puts "DEBUG: #{repo}: #{collaborator['login']}: #{collaborator['permissions']}" if @loglevel == 'debug'
        if collaborator['permissions']['admin'] == true
          $privs = 'Admin'
        elsif collaborator['permissions']['push'] == true
          $privs = 'Write'
        elsif collaborator['permissions']['pull'] == true
          $privs = 'Read Only'
        end
      end
    end

    if member != true
      puts "DEBUG: #{repo}: #{user} is not in the list of collaborators" if @loglevel == 'debug'
      $privs = 'No Access'
    end

  elsif result['message'] == 'Must have push access to view repository collaborators.'
    $privs = 'Read Only'
    puts "DEBUG: #{repo}: #{user}: #{result['message']}" if @loglevel == 'debug'
  else
    # This last else clause shouldn't be necessary as the list of repos returned by get_user_repos should always 
    # be readable. Leaving this here to see if that behavior changes after we move to internal repos
    $privs = 'No Access'
    puts "DEBUG: #{repo}: #{user}: #{result['message']}" if @loglevel == 'debug'
  end

  $privs
end

def get_repo_collaborator_info(repo, collaborator, token)
  # https://github.com/api/v3/repos/dnlloyd/cookbook-multipath/collaborators{/collaborator}
  collaborators = []
  
  response, result = api_call_with_auth( 'repos', "#{repo}/collaborators/#{collaborator}", '', token)

  if response.code == '200'
    puts result['login']
  else
    puts result
  end
end

def get_collaborator(repo, collaborator, token)
  response, result = api_call_with_auth( 'repos', "#{repo}/collaborators/#{collaborator}", '', token)

  result.each do |k,v|
    puts "#{k}: #{v}"
  end
end

def get_orgs(org, token)
  # https://github.com/api/v3/orgs/{org}
  collaborators = {}
  
  response, result = api_call_with_auth( 'orgs', "#{org}/", '', token)

  result.each do |k,v|
    puts "#{k}: #{v}"
  end
end

def get_org_members(org, user, token)
  # https://github.com/api/v3/orgs/{org}/members{/member}
  
  response, result = api_call_with_auth( 'orgs', "#{org}/memberships/#{user}", '', token)

  if response.code == '200'
    role = result['role']
  else
    role = result['message']
  end

  role
end

username = get_user(token)
puts "User: #{username.bold}\n\n"

# Need to check if this returns Internal repos as well
# This does not return Private repos
# puts 'User\'s Public Repositories:'
repos = get_user_repos(username, token)
# repos.each do |repo|
#   puts repo.light_blue
# end
# puts ''

puts 'User\'s Repository Permissions:'
repos.each do |repo|
  privs = get_repo_collaborators(repo, username, token)

  case privs
  when 'Read Only'
    puts "#{repo.light_blue}: #{privs.green}"
  when 'Write'
    puts "#{repo.light_blue}: #{privs.yellow}"
  when 'Admin'
    puts "#{repo.light_blue}: #{privs.red}"
  end
end
puts ''

puts 'User\'s Private Repository Permissions:'
private_repos.each do |repo|
  private_privs = get_repo_collaborators(repo, username, private_repo_token)

  case private_privs
  when 'Read Only'
    puts "#{repo.light_blue}: #{private_privs.green}"
  when 'Write'
    puts "#{repo.light_blue}: #{private_privs.yellow}"
  when 'Admin'
    puts "#{repo.light_blue}: #{private_privs.red}"
  when 'No Access'
    puts "#{repo.light_blue}: #{private_privs}"
  end
end

if get_user_org_info == true
  puts ''
  puts 'User\'s Organizations:'
  orgs = get_user_orgs(username, token)
  orgs.each do |org|
    puts org.red
  end
  puts ''

  puts 'User\'s Organizations Member Status:'
  orgs.each do |org|
    role = get_org_members(org, username, token)

    case role
    when 'member'
      puts "#{org.light_blue}: #{role.red}"
    when 'admin'
      puts "#{org.light_blue}: #{role.red}"
    else
      puts "#{org.light_blue}: #{role}"
    end
  end
end

# TODO: Get user's teams. get user's teams repos, check privs on those repos.
# Update: teams are not discoverable via a query against a user therefor this is not
# a viable strategy. I.e. you would have to query every tram in github to determine team membership

puts 'User\'s Other Repository Permissions:'
other_repos.each do |repo|
  other_privs = get_repo_collaborators(repo, username, private_repo_token)

  case other_privs
  when 'Read Only'
    puts "#{repo.light_blue}: #{other_privs.green}"
  when 'Write'
    puts "#{repo.light_blue}: #{other_privs.yellow}"
  when 'Admin'
    puts "#{repo.light_blue}: #{other_privs.red}"
  when 'No Access'
    puts "#{repo.light_blue}: #{other_privs}"
  end
end

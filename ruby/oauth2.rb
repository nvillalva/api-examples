require 'rubygems'
require 'bundler/setup'

# gem install oauth2 if not already installed
require 'oauth2'
require 'faraday'
require 'json'
require 'launchy'
require 'webrick'


# The following should be populated with your app's information
#  CLIENT_ID and CLIENT_SECRET are issued by mashery
#  redirect_uri is the callback uri as configured in mashery
CLIENT_ID = '<redacted>'
CLIENT_SECRET = '<redacted>'
redirect_uri = 'http://localhost.mapmyapi.com:12345/callback/'

# Once you have an access token for your test user, feel free to
# paste it here to avoid having to authorize for each test
ACCESS_TOKEN = 'update me after first run'

site = 'https://oauth2-api.mapmyapi.com/v7.0/'
authorize_uri = 'https://www.mapmyfitness.com/v7.0/oauth2/authorize/'
access_token_url = 'https://oauth2-api.mapmyapi.com/v7.0/oauth2/access_token/'

# Set up a Faraday connection to the oauth2 API server for use later
conn = Faraday.new(:url => 'https://oauth2-api.mapmyapi.com/v7.0/') do |faraday|
  faraday.request  :url_encoded
  faraday.response :logger
  faraday.adapter Faraday.default_adapter
end

# AT should be 40 hexadecimal characters. If it isn't then we need to get a new one
if ACCESS_TOKEN == nil or ACCESS_TOKEN.length != 40 or ACCESS_TOKEN.match('[0-9a-f]{40}') == nil then  # Get an access token  
  authorize_uri = "#{authorize_uri}?client_id=#{CLIENT_ID}&response_type=code&redirect_uri=#{redirect_uri}"
  # Open the web browser so we can authorize this application
  Launchy.open(authorize_uri)
  
  $auth_code = nil  
  server = WEBrick::HTTPServer.new :Port => 12345
  class SimpleAuthCodeHandler < WEBrick::HTTPServlet::AbstractServlet
    def do_GET request, response
      puts request.query['code']
      $auth_code = request.query['code']
      response.status = 200
      response.body = "Success. Please close this window and use Ctrl-C to stop the server and continue with the tutorial."
    end
  end
  server.mount '/callback/', SimpleAuthCodeHandler
  trap 'INT' do server.shutdown end
  server.start
  
  code = $auth_code
  puts "","Requesting the access_token based on the code we received"
  response = conn.post do |req|
    req.url 'oauth2/access_token'
    req.headers['Api-Key'] = CLIENT_ID
    req.body = {:grant_type => 'authorization_code', :client_id => CLIENT_ID, :client_secret => CLIENT_SECRET, :code => code}
  end

  if not response.success? then
    puts "",
         "Request failed. Examine the logging above for clues as to the error"
    abort
  end

  token_info = JSON.parse(response.body)

  access_token = token_info["access_token"]
  refresh_token = token_info["refresh_token"]
  puts "",
     "Received access token",
     "\taccess_token: #{access_token}",
     "\trefresh_token: #{refresh_token}"
  ACCESS_TOKEN = access_token
end

# Exercise the API
# Get User info for authenticated user
response = conn.get do |req|
  req.url 'user/self/'
  req.headers['Api-Key'] = CLIENT_ID
  req.headers['Authorization'] = "Bearer #{ACCESS_TOKEN}"
end
puts "Got user info:", JSON.parse(response.body).inspect

# Get Routes near a location
response = conn.get do |req|
  req.url 'route/'
  req.headers['Api-Key'] = CLIENT_ID
  req.headers['Authorization'] = "Bearer #{ACCESS_TOKEN}"
  req.params = {:city => 'austin', :state => 'tx', :country => 'us', :limit => 10}
end

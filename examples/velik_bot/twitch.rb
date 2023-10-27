# 1. create app: https://dev.twitch.tv/console/apps/create
#    set OAuth Redirect URL: http://localhost:8000
# 2. find client_id and create client_secret on apps properties page
# 3. obtain auth code by opening in web browser
#    chat read+write example: https://id.twitch.tv/oauth2/authorize?response_type=code&client_id=<client_id>&redirect_uri=http://localhost:8000&scope=chat:read+chat:edit
# 4. get tokens: $ curl https://id.twitch.tv/oauth2/token -d "client_id=$(cat twitch_client_id.secret.txt)&client_secret=$(cat twitch_client_secret.secret.txt)&grant_type=authorization_code&code=<auth_code>&redirect_uri=http://localhost:8000" >twitch.secret.json
module Twitch
  def self.configure client_id, client_secret, tokens_filename
    @client_id = client_id
    @client_secret = client_secret
    @tokens_filename = tokens_filename
  end
  def self.refresh
    ::File.write @tokens_filename, ::NetHTTPUtils.request_data("https://id.twitch.tv/oauth2/token", :POST, form: {
      client_id: @client_id || raise(Error, "missing configuration (#{::Module.nesting}.configure)"),
      client_secret: @client_secret || raise(Error, "missing configuration (#{::Module.nesting}.configure)"),
      grant_type: "refresh_token",
      refresh_token: ::JSON.load(::File.read(@tokens_filename)).fetch("refresh_token")
    } )
  end
  def self.request mtd, retry_delay = 5, **form
    ::JSON.load begin
      ::NetHTTPUtils.request_data "https://api.twitch.tv/helix/#{mtd}", form: form, header: {
        "Authorization" => "Bearer #{::JSON.load(::File.read(@tokens_filename)).fetch "access_token"}",
        "client-id" => @client_id || raise(Error, "missing configuration (#{::Module.nesting}.configure)")
      }
    rescue ::NetHTTPUtils::Error
      fail unless '{"error":"Unauthorized","status":401,"message":"Invalid OAuth token"}' == $!.body
      refresh
      sleep retry_delay
      retry
    end
  end
end

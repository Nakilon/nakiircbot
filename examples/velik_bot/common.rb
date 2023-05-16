require "nethttputils"
require "json"

def refresh
  File.write "tokens.secret", NetHTTPUtils.request_data("https://id.twitch.tv/oauth2/token", :POST, form: {
    client_id: File.read("clientid.secret"),
    client_secret: File.read("secret.secret"),
    grant_type: "refresh_token",
    refresh_token: JSON.load(File.read("tokens.secret"))["refresh_token"]
  } )
end
def clip where, input
  request = lambda do |mtd, **form|
    JSON.load begin
      NetHTTPUtils.request_data \
      "https://api.twitch.tv/helix/#{mtd}",
      form: form,
      header: {
        "Authorization" => "Bearer #{JSON.load(File.read("tokens.secret"))["access_token"]}",
        "client-id" => File.read("clientid.secret")
      }
    rescue NetHTTPUtils::Error
      fail unless '{"error":"Unauthorized","status":401,"message":"Invalid OAuth token"}' == $!.body
      refresh
      sleep 5
      retry
    end
  end
  user_id = request["users", "login" => where[/\A#*(.+)/, 1]]["data"][0]["id"]
  f = lambda do |cursor = nil|
    t = request["clips", broadcaster_id: user_id, first: 100, **(cursor ? { after: cursor } : {})]
    t["data"] + t["pagination"]["cursor"].then{ |_| _ ? f[_] : [] }
  end
  f.call.
    sort_by{ |_| -_["view_count"] }.
    min_by{ |_| DidYouMean::Levenshtein.distance _["title"].downcase.squeeze, input.downcase }.
    then{ |_| _.values_at("title", "url").join " " }
end

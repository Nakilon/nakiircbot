# TODO: add mutex
threaded = lambda do |&block|
  Thread.new do
    block.call
  rescue StandardError, WebMock::NetConnectNotAllowedError
    puts $!.full_message
  end
end

prev_goons_time = Time.now - 120
require "json"

require "nethttputils"
refresh = lambda do
  File.write "tokens.secret", NetHTTPUtils.request_data("https://id.twitch.tv/oauth2/token", :POST, form: {
    client_id: File.read("clientid.secret"),
    client_secret: File.read("secret.secret"),
    grant_type: "refresh_token",
    refresh_token: JSON.load(File.read("tokens.secret"))["refresh_token"]
  } )
end

require "nakiircbot"
NakiIRCBot.start(
  "irc.chat.twitch.tv", "6667", "velik_bot", "nakilon", "",
  "#velik_bot", "#ta_samaya_lera", "#sonya_mercury",
  password: "oauth:"+JSON.load(File.read("tokens.secret"))["access_token"]
) do |str, add_to_queue, restart_with_new_password, who, where, what|
  if ":tmi.twitch.tv NOTICE * :Login authentication failed" == str
    refresh.call
    next restart_with_new_password.call "oauth:"+JSON.load(File.read("tokens.secret"))["access_token"]
  end

  next unless who   # not PRIVMSG

  next if NakiIRCBot::Common.ping add_to_queue.curry[where], what #if where == "#velik_bot"

  where.downcase!

  next add_to_queue.call where, "спокойной ночи, @lezhebok" if "#ta_samaya_lera" == where && "lezhebok" == who && (what.downcase["я спать"] || what.downcase["спокойной"])

  if /\A\\(клип|clip) (?<input>.+)/ =~ what
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
        refresh.call
        sleep 5
        retry
      end
    end
    threaded.call do
      user_id = request["users", "login" => where[/\A#*(.+)/, 1]]["data"][0]["id"]
      f = lambda do |cursor = nil|
        t = request["clips", broadcaster_id: user_id, first: 100, **(cursor ? { after: cursor } : {})]
        t["data"] + t["pagination"]["cursor"].then{ |_| _ ? f[_] : [] }
      end
      add_to_queue.call where, f.call.
        sort_by{ |_| -_["view_count"] }.
        min_by{ |_| DidYouMean::Levenshtein.distance _["title"].downcase.squeeze, input.downcase }.
        then{ |_| _.values_at("title", "url").join " " }
    end
  end

  if %w{ #ta_samaya_lera }.include? where
    old = File.exist?("goons.txt") ? File.read("goons.txt") : "?"
    next add_to_queue.call where, "@#{who}, Goons were last seen at #{old}" if "\\goons" == what
    if 60 < Time.now - prev_goons_time
      threaded.call do
        location = JSON.load(NetHTTPUtils.request_data("https://congested-valleygirl-9254455.herokuapp.com/goonDetectors")).first["location"]
        if old != location
          add_to_queue.call "#ta_samaya_lera", "Goons have moved from #{old} to #{location}"
          # add_to_queue.call "#feerplaytv", "Goons have moved from #{old} to #{location}"
          File.write "goons.txt", location
        end
      end
      prev_goons_time = Time.now
    end
  end
end

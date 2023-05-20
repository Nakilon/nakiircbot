# TODO: add mutex
threaded = lambda do |*args, &block|
  Thread.new *args do |*args|
    block.call *args
  rescue StandardError, WebMock::NetConnectNotAllowedError
    puts $!.full_message
  end
end

prev_goons_time = Time.now - 120

require_relative "common"

require "nakiircbot"
NakiIRCBot.start(
  "irc.chat.twitch.tv", "6667", "velik_bot", "nakilon", "",
  "#velik_bot", "#ta_samaya_lera", "#sonya_mercury",
  password: "oauth:"+JSON.load(File.read("tokens.secret"))["access_token"]
) do |str, add_to_queue, restart_with_new_password, who, where, what|
  if ":tmi.twitch.tv NOTICE * :Login authentication failed" == str
    refresh
    next restart_with_new_password.call "oauth:"+JSON.load(File.read("tokens.secret"))["access_token"]
  end

  next unless who   # not PRIVMSG

  next if NakiIRCBot::Common.ping add_to_queue.curry[where], what #if where == "#velik_bot"

  where.downcase!

  next add_to_queue.call where, "спокойной ночи, @lezhebok" if "#ta_samaya_lera" == where && "lezhebok" == who && (what.downcase["я спать"] || what.downcase["спокойной"])

  if /\A\\(клип|clip) (?<input>.+)/ =~ what
    threaded.call where.dup, input.dup do |where, input|
      add_to_queue.call where, Common.clip(where, input)
    end
  end

  if /\A\\(цена|price) (?<input>.+)/ =~ what
    threaded.call where.dup, input.dup, who.dup do |where, input, who|
      add_to_queue.call where, "@#{who}, #{Common.price input}"
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
          File.write "goons.txt", location
        end
      end
      prev_goons_time = Time.now
    end
  end
end

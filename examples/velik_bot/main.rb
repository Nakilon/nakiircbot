STDOUT.sync = true

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
Common.init_repdb "prod"

channels, features = YAML.load_file("prod.cfg.yaml")

require "nakischema"
require "nakiircbot"
NakiIRCBot.start(
  "irc.chat.twitch.tv", "6667", "velik_bot", "nakilon", "", *channels,
  password: "oauth:"+JSON.load(File.read("tokens.secret"))["access_token"]
) do |str, add_to_queue, restart_with_new_password, who, where, what|
  if ":tmi.twitch.tv NOTICE * :Login authentication failed" == str
    refresh
    next restart_with_new_password.call "oauth:"+JSON.load(File.read("tokens.secret"))["access_token"]
  end

  next unless who   # not PRIVMSG

  next if %w{ ynh56 }.include? who.downcase

  respond = add_to_queue.curry[where]

  next if NakiIRCBot::Common.ping respond, what

  query = what.split

  if /\A@?velik_bot/ === query[0] && query[1]
    sleep [File.mtime("gpt.touch") - Time.now + 30, 0].max if File.exist? "gpt.touch"
    FileUtils.touch "gpt.touch"
    next threaded.call ->s{->r{respond.call s+r}}["#{who}, "], query.drop(1).join(" ") do |callback, query|
      get_json = lambda do |model|
        NetHTTPUtils.request_data "https://chimeragpt.adventblocks.cc/api/v1/chat/completions", :POST, :json,
          header: {"Authorization" => "Bearer #{File.read "gpt.secret"}"},
          form: {
            "model" => model,
            "max_tokens" => 100,
            "messages" => [{"role" => "user", "content" => query}],
          }
      end
      JSON.load(
        begin
          get_json["gpt-4"]
        rescue NetHTTPUtils::Error
          fail unless 400 == $!.code && '{"detail":"Unhandled Exception: The provider does not respond!"}' == $!.body
          get_json["gpt-3.5-turbo"]
        end
      ).tap do |json|
        Nakischema.validate json, { hash: {
          "choices" => [[
            { hash: {
              "finish_reason" => "stop",
              "index" => 0..0,
              "message" => { hash: {"content" => String, "role" => "assistant"} },
            } },
          ]],
          "created" => Integer,
          "id" => String,
          "model" => String,
          "object" => "chat.completion",
          "usage" => { hash: {"completion_tokens" => Integer, "prompt_tokens" => Integer, "total_tokens" => Integer} },
        } }
      end["choices"][0]["message"]["content"].then &callback
    end
  end

  where.downcase!

  if /\A\\(клип|clip)\s+(?<input>.+)/ =~ what
    next threaded.call where.dup, input.dup do |where, input|
      add_to_queue.call where, Common.clip(where, input)
    end
  end

  next add_to_queue.call where, Common.rep_read(  where, what.split[1].delete_prefix("@")      ) if "?rep" == what.split[0].downcase && what.split[1]
  next add_to_queue.call where, Common.rep_read(  where, who                                   ) if "?rep" == what.split[0].downcase
  next add_to_queue.call where, Common.rep_plus(  where, who, what.split[1].delete_prefix("@") ) if "+rep" == what.split[0].downcase && what.split[1]
  next add_to_queue.call where, Common.rep_minus( where, who, what.split[1].delete_prefix("@") ) if "-rep" == what.split[0].downcase && what.split[1]

  if /\A\\(цена|price)\s+(?<input>.+)/ =~ what
    next threaded.call where.dup, input.dup, who.dup do |where, input, who|
      add_to_queue.call where, "@#{who}, #{ if "ушки" == input
        "Прапор купит \"Ушки ta_samaya_lera\" за #{rand 20000..30000} ₽"
      else
        Common.price input
      end }"
    end
  end

  next add_to_queue.call where, "спокойной ночи, @lezhebok" if "#ta_samaya_lera" == where && "lezhebok" == who && (what.downcase["я спать"] || what.downcase["спокойной"])

  next unless [
    ["#vellrein", "внизу"],
    ["#nekochan_myp", "вверху"],
  ].each do |w, word|
    next unless w == where && Common.is_asking_track(what)
    add_to_queue.call where, [
      "@#{who}, название трека отображается #{word}",
      "@#{who}, название трека #{word} отображается",
      "@#{who}, #{word} отображается текущий трек",
      "@#{who}, трек #{word} отображается",
      "@#{who}, музыка #{word} отображается",
    ].sample
    break
  end

  old = File.exist?("goons.txt") ? File.read("goons.txt") : "?"
  next add_to_queue.call where, "Goons were last seen at #{old}" if "\\goons" == what
  if %w{ #ta_samaya_lera #korolikarasi }.include? where
    if 60 < Time.now - prev_goons_time
      threaded.call do
        location = JSON.load(NetHTTPUtils.request_data("https://congested-valleygirl-9254455.herokuapp.com/goonDetectors")).first["location"]
        if old != location
          add_to_queue.call "#ta_samaya_lera", "Goons have moved from #{old} to #{location}"
          add_to_queue.call "#korolikarasi", "Goons have moved from #{old} to #{location}"
          File.write "goons.txt", location
        end
      end
      prev_goons_time = Time.now
    end
  end

end

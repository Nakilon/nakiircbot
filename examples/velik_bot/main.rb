STDOUT.sync = true

# TODO: add mutex
threaded = lambda do |*args, &block|
  Thread.new *args do |*args|
    block.call *args
  rescue StandardError, WebMock::NetConnectNotAllowedError
    puts $!.full_message
  end
end


require_relative "common"
Common.init_repdb "prod"

# static
channels, goons_channels = YAML.load_file("prod.cfg.yaml")
features = {
  goons_regular_report: false,
}
cfg = YAML::Store.new "dynamic.cfg.yaml"

prev_goons_time = Time.now - 120

require "nakiircbot"
require "yaml"
require "time"
NakiIRCBot.start(
  "irc.chat.twitch.tv", "6667", "velik_bot", "lzhesh_zaviduesh_zlishsya", "", *channels,
  password: "oauth:"+JSON.load(File.read("tokens.secret"))["access_token"]
) do |str, add_to_queue, restart_with_new_password, who, where, what|

  if ":tmi.twitch.tv NOTICE * :Login authentication failed" == str
    refresh
    restart_with_new_password.call "oauth:"+JSON.load(File.read("tokens.secret"))["access_token"]
    next
  end
  next unless who   # not PRIVMSG
  next if %w{ ynh56 }.include? who.downcase

  respond = ->_{ add_to_queue.call where, _.gsub("\n", " ") }

  next if NakiIRCBot::Common.ping respond, what

  query = what.split

  if /\A(@?velik_bot|velik|велик)[,:]?\z/i === query[0] && query[1] && !cfg.transaction(true){ |db| db.fetch(:gpt_ignore, {})[who.downcase] }
    while 0 < t = File.mtime("gpt.touch") - Time.now + 20
      sleep t
    end if File.exist? "gpt.touch"
    FileUtils.touch "gpt.touch"
    next threaded.call ->s{->r{respond.call s+r}}["#{who}, "], query.drop(1).join(" ") do |callback, query|
      callback.call Common.chatai query
    end
  end
  if "\\ignore" === query[0] && query[1] && "lzhesh_zaviduesh_zlishsya" === who
    t = query[1].delete_prefix("@").downcase
    next add_to_queue.call where, "#{
      "un" unless cfg.transaction do |db|
        db[:gpt_ignore] ||= {}
        db[:gpt_ignore][t] = !db[:gpt_ignore][t]
      end
    }ignored #{t.inspect}"
  end

  help = []

  where.downcase!

  help.push "\\lastclip - последний twitch клип"
  if %w{ \lastclip } == query
    next threaded.call where.dup do |where|
      add_to_queue.call where, Common.clips(where).max_by{ |_| _["created_at"] }.fetch("url")
    end
  end
  help.push "\\clip <запрос> - найти клип по названию"
  if /\A\\(clip|клип)\s+(?<input>.+)/ =~ what
    next threaded.call where.dup, input.dup do |where, input|
      add_to_queue.call where, Common.clip(where, input)
    end
  end
  help.push "\\clip_from <канал> <запрос> - найти клип с другого канала"
  if /\A\\clip_from\s+(?<from>\S+)\s+(?<input>.+)/ =~ what
    next threaded.call where.dup, input.dup do |where, input|
      add_to_queue.call where, Common.clip(from, input)
    end
  end

  help.push "?rep - узнать свою репутацию на канале"
  help.push "+rep <кто> - повысить чужую репутацию"
  help.push "-rep <кто> - понизить чужую репутацию"
  # TODO: should it fail on blank `what` (from tests)?
  next add_to_queue.call where, Common.rep_read(  where, what.split[1].delete_prefix("@")      ) if "?rep" == what.split[0].downcase && what.split[1]
  next add_to_queue.call where, Common.rep_read_precise( where, who                            ) if "?rep" == what.split[0].downcase
  next add_to_queue.call where, Common.rep_plus(  where, who, what.split[1].delete_prefix("@") ) if "+rep" == what.split[0].downcase && what.split[1]
  next add_to_queue.call where, Common.rep_minus( where, who, what.split[1].delete_prefix("@") ) if "-rep" == what.split[0].downcase && what.split[1]

  help.push "\\price, \\цена - узнать цену предмета в EFT"
  if /\A\\(price|цена)\s+(?<input>.+)/ =~ what
    next threaded.call where.dup, input.dup, who.dup do |where, input, who|
      add_to_queue.call where, "@#{who}, #{ if "ушки" == input
        "Прапор купит \"Ушки ta_samaya_lera\" за #{rand 20000..30000} ₽"
      else
        Common.price input
      end }"
    end
  end

  help.push "\\song, \\песня - текущий музыкальный трек"
  if user = {
    "#korolikarasi" => "korolikarasi",
    "#ta_samaya_lera" => "colaporter",
  }[where]
    next threaded.call do
      JSON.load(
        NetHTTPUtils.request_data "https://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user=#{user}&api_key=#{File.read "lastfm.secret"}&format=json&limit=1"
      )["recenttracks"]["track"][0].then{ |_| respond.call "🎶 #{_["artist"]["#text"]} - #{_["name"]}" }
    end if /\A\\(song|песня)\z/ === query[0] || Common.is_asking_track(what)
  else
  next unless [
    # ["#vellrein", "внизу"],
    ["#nekochan_myp", "вверху"],
  ].each do |w, word|
    next unless w == where
    next unless /\A\\(song|песня)\z/ === query[0] || Common.is_asking_track(what)
    add_to_queue.call where, [
      "@#{who}, название трека отображается #{word}",
      "@#{who}, название трека #{word} отображается",
      "@#{who}, #{word} отображается текущий трек",
      "@#{who}, трек #{word} отображается",
      "@#{who}, музыка #{word} отображается",
    ].sample
    break
  end
    next respond.call "no integration with #{where}" if /\A\\(song|песня)\z/ === query[0]
  end

  help.push "\\goons - узнать, где сейчас гуны"
  goons_file = "goons.yaml"
  (old, old_time) = File.exist?(goons_file) ? YAML.load_file(goons_file) : ["?", nil]
  next add_to_queue.call where, "Goons were last seen at #{old} (#{Time.parse(old_time).strftime "%c"})" if "\\goons" == what && old_time
  if goons_channels.include? where
    if 60 < Time.now - prev_goons_time
      threaded.call do
        _, _, location, time = Oga.parse_html(NetHTTPUtils.request_data "https://docs.google.com/spreadsheets/u/0/d/e/2PACX-1vRwLysnh2Tf7h2yHBc_bpZLQh6DiFZtDqyhHLYP022xolQUPUHkSModV31E5Y7cLh_8LZGexpXy2VuH/pubhtml/sheet?headers=false&gid=1420050773").css("td").map(&:text).tap do |_|
          Nakischema.validate _, [["Map Selection:", "Timestamp", String, /\A\d+\/\d+\/202\d \d+:\d\d:\d\d\z/]]
        end
        if old != location
          goons_channels.each{ |channel| add_to_queue.call channel, "Goons have moved from #{old} to #{location}" } if features[:goons_regular_report]
          File.write goons_file, YAML.dump([location, time])
        end
      end
      prev_goons_time = Time.now
    end
  end

  # help.push "\\?, \\h, \\help, \\справка <команда> - получить справку по отдельной команде"
  if /\A\\(\?|h(elp)?|х(елп)?|справка|помощь)\z/ === query[0]
  end
  # help.push "\\?, \\help, \\команды - узнать доступные команды"
  if /\A\\(\?|help|команды)\z/ === query[0]
    next respond.call "доступные команды: #{help.map{ |_| _[/\\?(\S+?),? /, 1] }.join(", ")} -- используйте \\help <команда> для получения справки по каждой"
  end

  next add_to_queue.call "#korolikarasi", "#{where} <#{who}> #{what}" if /карас/i =~ what && "#korolikarasi" != where
  next add_to_queue.call where, "спокойной ночи, @lezhebok" if "#ta_samaya_lera" == where && "lezhebok" == who && (what.downcase["я спать"] || what.downcase["спокойной"])

end

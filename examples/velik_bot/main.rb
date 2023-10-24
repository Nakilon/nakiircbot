STDOUT.sync = true



require_relative "common"
Common.init_repdb "prod"

# static
channels, goons_channels = YAML.load_file("prod.cfg.yaml")
features = {
  goons_regular_report: false,
}
cfg = YAML::Store.new "dynamic.cfg.yaml"
quotes = YAML::Store.new "quotes.yaml"

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
  next unless where.start_with? ?#
  next if %w{ ynh56 }.include? who.downcase

  respond = ->_{ add_to_queue.call where, _.gsub("\n", " ") }

  next if NakiIRCBot::Common.ping respond, what

  chatai = lambda do |who, what|
    while 0 < t = File.mtime("gpt.touch") - Time.now + 20
      sleep t
    end if File.exist? "gpt.touch"
    FileUtils.touch "gpt.touch"
    next Common::threaded ->s{->r{respond.call s+r}}["#{who}, "], what do |callback, query|
      callback.call Common::chatai query
    end
  end

  where.downcase!

  if "#vellrein" === where && "4ertovka_ashley" === who.downcase
    unless File.exist?("ashley.touch") && File.mtime("ashley.touch") + 1800 > Time.now
      FileUtils.touch "ashley.touch"
      next chatai.call "4ertovka_ashley", "скажи что-нибудь едкое и неуважительное для 4ertovka_ashley в контексте ее сообщения \"#{what}\""
    end
  end

  query = what.split

  if /\A(@?velik_bot|velik|велик)[,:]?\z/i === query[0] && query[1] && !cfg.transaction(true){ |db| db.fetch(:gpt_ignore, {})[who.downcase] }
    next chatai.call who, query.drop(1).join(" ")
  end
  if "\\ignore" === query[0] && query[1] && "lzhesh_zaviduesh_zlishsya" === who
    t = query[1].delete_prefix("@").downcase
    next respond.call "#{
      "un" unless cfg.transaction do |db|
        db[:gpt_ignore] ||= {}
        db[:gpt_ignore][t] = !db[:gpt_ignore][t]
      end
    }ignored #{t.inspect}"
  end

  help = []

  help.push "\\access_quote <кто> -- изменить права указанного пользователя на добавление цитат"
  if "\\access_quote" === query[0] && query[1]
    next respond.call "only channel owner can toggle \\qadd and \\qdel access" unless where === ?# + who.downcase
    name = query[1].delete_prefix("@").downcase
    b = cfg.transaction do |db|
      db[[:access_quote, where]] ||= {}
      db[[:access_quote, where]][name] = !db[[:access_quote, where]][name]
    end
    next respond.call "#{b ? "add" : "remov"}ed \\qadd and \\qdel access for #{name.inspect}"
  end
  help.push "\\q, \\quote [<номер>] -- выдать цитату под указанным номером либо случайную"
  if /\A\\q(uote)?\z/ === query[0]
    next respond.call(( quotes.transaction do |db|
      db[where] ||= []
      next "no quotes yet, go ahead and use '\\qadd <text>' to add some!" if db[where].none?
      if query[1]
        if (i = query[1].to_i).zero?
          (quote, author), i = smart_match(query.drop(1).join(" "), db[where].map.with_index.select(&:first).to_a){ |(quote, author), i| quote }
          author ? "##{i+1}: #{quote}" : fail
        else
          quote, author = db[where][i-1]
          author ? "##{i}: #{quote}" : "quote ##{i} not found"
        end
      else
        (quote, author), i = db[where].map.with_index.select(&:first).to_a.sample
        author ? "##{i+1}: #{quote}" : "no quotes yet, go ahead and use '\\qadd <text>' to add some!"
      end
    end ))
  end
  help.push "\\qadd <цитата> -- добавить цитату в цитатник"
  if /\A\\qadd\z/ === query[0] && query[1]
    next respond.call "only channel owner add those added using \\access_quote are allowed to add quotes" unless where === ?# + who.downcase || cfg.transaction(true){ |db| db.fetch([:access_quote, where], {})[who.downcase] }
    next respond.call(( quotes.transaction do |db|
      db[where] ||= []
      db[where].push [query.drop(1).join(" "), who.downcase]
      "quote ##{db[where].size} added"
    end ))
  end
  help.push "\\qdel <номер> -- удалить цитату под указанным номером"
  if /\A\\qdel\z/ === query[0] && query[1]
    next respond.call "only channel owner add those added using \\access_quote are allowed to add quotes" unless where === ?# + who.downcase || cfg.transaction(true){ |db| db.fetch([:access_quote, where], {})[who.downcase] }
    next respond.call "bad index #{query[1].inspect}, must be a natural number" unless i = Integer(query[1], exception: false)
    next respond.call(( quotes.transaction do |db|
      db[where] ||= []
      next "quote ##{i} not found" unless db[where][i-1]
      db[where][i-1] = nil
      "quote ##{i} deleted"
    end ))
  end

  help.push "\\ктоя - узнать, какой Дикий ты сегодня"
  if "\\ктоя" === query[0].downcase
    a, b = File.read("scav_names.txt").split("\n\n").map(&:split)
    d = Digest::SHA512.hexdigest(who.downcase + Date.today.ajd.to_s).hex % 0x100000000
    next respond.call "сегодня (#{Date.today.strftime "%F"}) #{who} -- #{a.rotate(d).first} #{b.rotate(d).first}"
  end

  help.push "\\lastclip - последний twitch клип"
  if %w{ \\lastclip } == query
    next Common::threaded where.dup do |where|
      respond.call Common.clips(where).max_by{ |_| _["created_at"] }.fetch("url")
    end
  end
  help.push "\\clip <запрос> - найти клип по названию"
  if /\A\\(clip|клип)\s+(?<input>.+)/ =~ what
    next Common::threaded where.dup, input.dup do |where, input|
      respond.call Common.clip(where, input)
    end
  end
  help.push "\\clip_from <канал> <запрос> - найти клип с другого канала"
  if /\A\\clip_from\s+(?<from>\S+)\s+(?<input>.+)/ =~ what
    next Common::threaded where.dup, input.dup do |where, input|
      respond.call Common.clip(from, input)
    end
  end

  help.push "?rep - узнать свою репутацию на канале"
  help.push "+rep <кто> - повысить чужую репутацию (доступно раз в сутки по отношению к одному человеку)"
  help.push "-rep <кто> - понизить чужую репутацию (доступно раз в сутки по отношению к одному человеку)"
  # TODO: should it fail on blank `what` (from tests)?
  next respond.call Common.rep_read(  where, what.split[1].delete_prefix("@")      ) if "?rep" == what.split[0].downcase && what.split[1]
  next respond.call Common.rep_read_precise( where, who                            ) if "?rep" == what.split[0].downcase
  next respond.call Common.rep_plus(  where, who, what.split[1].delete_prefix("@") ) if "+rep" == what.split[0].downcase && what.split[1]
  next respond.call Common.rep_minus( where, who, what.split[1].delete_prefix("@") ) if "-rep" == what.split[0].downcase && what.split[1]

  help.push "\\price, \\цена - узнать цену предмета в EFT"
  if /\A\\(price|цена)\s+(?<input>.+)/ =~ what
    next Common::threaded where.dup, input.dup, who.dup do |where, input, who|
      respond.call "#{ if "ушки" == input
        "Прапор купит \"Ушки ta_samaya_lera\" за #{rand 20000..30000} ₽"
      else
        Common.price input
      end }"
    end
  end

  help.push "\\song, \\песня - узнать текущий музыкальный трек стримера"
  if user = {
    "#korolikarasi" => "korolikarasi",
    "#ta_samaya_lera" => "colaporter",
  }[where]
    next Common::threaded do
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
    respond.call [
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

  #                      \goons
  #                          reg       reg
  # 60< include moved   UMn  UMn  --   UM
  # 60< exclude moved   UMn  UMn  --   --
  # 60> include moved   UMn  UMn  --   --
  # 60> exclude moved   UMn  UMn  --   --
  # 60< include stayed  URn  URn  --   U-
  # 60< exclude stayed  URn  URn  --   --
  # 60> include stayed  URn  URn  --   --
  # 60> exclude stayed  URn  URn  --   --
  help.push "\\goons - узнать, где сейчас гуны, согласно 'гунтрекеру'"
  goons_file = "goons.yaml"
  (old, old_time) = File.exist?(goons_file) ? YAML.load_file(goons_file) : ["?", nil]
  if "\\goons" === query[0].downcase || goons_channels.include?(where) && 60 < Time.now - prev_goons_time && features[:goons_regular_report]
      Common::threaded do
        _, _, location, time = Oga.parse_html(NetHTTPUtils.request_data "https://docs.google.com/spreadsheets/u/0/d/e/2PACX-1vRwLysnh2Tf7h2yHBc_bpZLQh6DiFZtDqyhHLYP022xolQUPUHkSModV31E5Y7cLh_8LZGexpXy2VuH/pubhtml/sheet?headers=false&gid=1420050773").css("td").map(&:text).tap do |_|
          Nakischema.validate _, [["Map Selection:", "Timestamp", String, /\A\d+\/\d+\/202\d \d+:\d\d:\d\d\z/]]
        end
        if old != location
        (goons_channels | [where]).each{ |channel| add_to_queue.call channel, "Goons have moved from #{old} to #{location}" }
          File.write goons_file, YAML.dump([location, time])
      elsif "\\goons" === query[0].downcase
        respond.call "Goons were last seen at #{old} (#{Time.strptime(time, "%m/%d/%Y %T").strftime "%c"})"
        end
      next if "\\goons" === query[0].downcase
      end
      prev_goons_time = Time.now
  end

  help.push "\\?, \\h, \\help [<команда>] - узнать все доступные команды или получить справку по указанной"
  if /\A\\(\?|h(elp)?)\z/ === query[0]
    main_cmds = help.map{ |_| [_[/(\\?\S+?),? /, 1], _] }.to_h
    next respond.call "доступные команды: #{main_cmds.keys.join(", ")} -- используйте #{query[0]} <команда> для получения справки по каждой" unless query[1]
    next respond.call help.flat_map{ |line| line[/(.+?) -/,].scan(/(?:\A|, )(\S+?)(?=,? )/).flatten.map{ |_| [_, line] } }.to_h.fetch query[1], "я не знаю команду #{query[1]}, я знаю только: #{main_cmds.keys.join(", ")}"
  end

  # next add_to_queue.call "#korolikarasi", "##{where[1]} <#{who}> #{what.delete "░█▄▀▐▌"}" if /[кk][аоao0][рp][аa][сc]/i =~ what && "#korolikarasi" != where
  next respond.call "спокойной ночи, @lezhebok" if "#ta_samaya_lera" == where && "lezhebok" == who && (what.downcase["я спать"] || what.downcase["спокойной"])

end

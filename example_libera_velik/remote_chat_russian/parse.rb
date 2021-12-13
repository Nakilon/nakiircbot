require "date"
nicknames = {}
nickname_regex = '[0-9A-Za-zА-Яа-яЁё_|\[\]{}\\\\\'"^-]+'
Dir.glob("sanitized/*").sort_by{ |_| Date.strptime File.basename(_), "%b%Y.txt" }.each do |filename|
  puts filename
  # next if File.exist? "parsed/#{File.basename filename}"
  messages = File.readlines(filename).map do |line|
    case line
    when "03 19:46 ::: Adalmina!~d5d24c04@castle.metka.ru has20:03 < Hyundai> что не удобно ? норм\n"
    when "03 23:47 < borod23:54 < shapirus> Filona!\n"
    when "05 06:25 ::: mode/#linux: +l 1209:35 < kpax15851> правда во втором они обещали нев гм очень быструю загрузку\n"
    when "07 09:12 < 09:15 ::: konaA_!payegul@85.186.211.27 has joined: #linux\n"
    when "07 09:209:35 < xeonium> amax: его зашлю на bbe.no-ip.org\n"
    when "07 09:56 ::: huffman_!~huffman@212.16.198.10 has joined: 10:10 ::: спит is now known as Dr][aM\n"
    when "16 00:46 ::: Kronas!Miranda@195.245.96.15 has quit:12:16 ::: borodatyi!~borodatyi@rocker.ksu.ru has joined: #linux\n"
    when "29 21:19 ::: PHoid!~root@ppp83-237-208-184.pppoe.mtu-net.ru has joined: #li21:26 <+зяфро> мну сломало клаву.)\n"
    when "17 19:09 < swa19:10 < IceD^> у мну довольно большая коллехсия цд\n"
    when "17 1921:30 ::: [FREEMAN]!~FREEMAN@217.151.18.172 has joined: #linux\n"
    when "04 13:27 adjkerntz:#linux Добро пожаловать на канал #bashorgfuns\n"   # wtf
    when /\A\d\d \d\d:\d\d( ::: #{nickname_regex}![^@\s]+@[-.0-9A-Za-z_]+(:31)?){1,2} has (?=\S)/
      # we assume this isn't enough to memorize for now
      # nicknames[$1] ||= 0
      # nicknames[$1] += 1
      case what = $'
      when /\A(quit|left #linux): /i
      when /\Ajoined: #linux\n/i
      # when /\Achanged nick to (\S+)\z/
      #   # nicknames[$1] ||= 0
      #   # nicknames[$1] += 1
      # when /\Aset topic: \S.+/
      else
        fail line.inspect
      end
    when /\A\d\d \d\d:\d\d ::: mode\/#linux: [+-].+ by #{nickname_regex}/
    when /\A\d\d \d\d:\d\d ::: ServerMode\/#[Ll]inux: [+-][a-z].* by (\*\.RusNet|[a-z]+\.([0-9A-Za-z-]+\.){0,3}[A-Za-z]+)\n\z/
    when /\A\d\d \d\d:\d\d ::: #{nickname_regex} was kicked from #[lL]inux by #{nickname_regex}: \S/
    when /\A\d\d \d\d:\d\d ::: #{nickname_regex} changed the topic of #linux to: \S/
    when /\A\d\d \d\d:\d\d ::: #{nickname_regex} is now known as #{nickname_regex}\n\z/
    when /\A\d\d \d\d:\d\d ::: Netsplit /
    when /\A\d\d \d\d:\d\d ::: Irssi: #linux: 1\d\d nicks \([^)]+\)\n\z/
    when /\A\d\d \d\d:\d\d ::: Irssi: Join to #linux was synced in \d\d secs\n\z/
    when /\A\d\d \d\d:\d\d ::: You're now known as (ramok|komar)(\d\d\d\d\d?)?\n\z/
    when /\A\d\d \d\d:\d\d <[ @+](#{nickname_regex})> /
      # unless %w{ world }.include? $1
        nicknames[$1] ||= 0
        nicknames[$1] += 1
      # end
      _ = $'.strip
      _.gsub(/(?<=\A|\s):-?[()|\\\/PD](?=\z|\s)/, "☺") unless %w{ }.include?($1) || _[/(ht|f)tps?:\/\//]
    when /\A\d\d \d\d:\d\d \* (#{nickname_regex}) (\S|\n\z)/
      nicknames[$1] ||= 0
      nicknames[$1] += 1
      $' unless %w{ }.include? $1
      nil   # we skip /me for now
    else
      fail line.inspect
    end
  end.compact.map(&:strip)
  # pp nicknames.sort_by(&:last)
  nicknames.delete "всем"
  dels = {}
  File.open("parsed/#{File.basename filename}", "w") do |filename_parsed|
    messages.each do |message|
      message = message.
        gsub(/<(\S+?)>/){                    nicknames.include?($1) ? (dels[$1] ||= 0; dels[$1] += 1; " ") : $& }.
        gsub(/(?<=\A|\s)(\S+?)(:|,|\s|\z)/){ nicknames.include?($1) ? (dels[$1] ||= 0; dels[$1] += 1; " ") : $& }. # this also relies on that nickname can't include : or ,
        strip.squeeze(" ")
      filename_parsed.puts message if message[" "] && message[/[а-я]/i]
    end
  end
  p dels.sort_by(&:last).map(&:first).reverse.first(20)
end

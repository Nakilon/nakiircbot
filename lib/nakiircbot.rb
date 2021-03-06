module NakiIRCBot
  class << self
    attr_accessor :queue
  end
  self.queue = []
  def self.start server, port, bot_name, master_name, welcome001, *channels, identity: nil, password: nil, masterword: nil, processors: [], tags: false
    # @@channels.replace channels.dup

    abort "matching bot_name and master_name may cause infinite recursion" if bot_name == master_name
    require "base64"
    require "fileutils"
    FileUtils.mkdir_p "logs"
    require "logger"
    original_formatter = Logger::Formatter.new
    logger = Logger.new "logs/txt", "daily",
                        progname: bot_name, datetime_format: "%y%m%d %H%M%S",
                        formatter: lambda{ |severity, datetime, progname, msg|
      puts "#{datetime.strftime "%H%M%S"} #{severity.to_s[0]} #{progname} #{msg.scrub.inspect[1..-2]}"
      original_formatter.call severity, datetime, progname, Base64.strict_encode64(msg)
      # TODO: maybe encode the whole string for a case of invalid progname?
    }
    logger.level = ENV["LOGLEVEL_#{name}"].to_sym if ENV.include? "LOGLEVEL_#{name}"
    puts "#{name} logger.level = #{logger.level}"

    # https://en.wikipedia.org/wiki/List_of_Internet_Relay_Chat_commands
    loop do
      logger.info "reconnect"
      require "socket"
      socket = TCPSocket.new server, port

      # https://stackoverflow.com/a/49476047/322020
      socket_send = lambda do |str|
        logger.info "> #{str}"
        socket.send str + "\n", 0
      end
      # socket.send "PASS #{password.strip}\n", 0 if twitch
      socket_send.call "CAP REQ :sasl" if password
      socket_send.call "NICK #{bot_name}"
      socket_send.call "USER #{bot_name} #{bot_name} #{bot_name} #{bot_name}" #unless twitch

      self.queue = []
      prev_socket_time = prev_privmsg_time = Time.now
      loop do
        begin
          addr, msg = self.queue.shift
          next unless addr && msg   # TODO: how is it possible to have only one of them?
          addr = addr.codepoints.pack("U*").tr("\x00\x0A\x0D", "")
          fail "I should not PRIVMSG myself" if addr == bot_name
          msg = msg.to_s.codepoints.pack("U*").chomp[/^(\x01*)(.*)/m,2].gsub("\x00", "[NUL]").gsub("\x0A", "[LF]").gsub("\x0D", "[CR]")
          privmsg = "PRIVMSG #{addr} :#{msg}"
          privmsg[-4..-1] = "..." until privmsg.bytesize <= 475
          prev_socket_time = prev_privmsg_time = Time.now
          socket_send.call privmsg
          break
        end until self.queue.empty? if prev_privmsg_time + 5 < Time.now || server == "localhost"

        unless _ = Kernel::select([socket], nil, nil, 1)
          break if Time.now - prev_socket_time > 300
          next
        end
        prev_socket_time = Time.now
        socket_str = _[0][0].gets chomp: true
        break unless socket_str
        str = socket_str.force_encoding("utf-8").scrub
        if /\A:\S+ 372 /.match? str   # MOTD
          logger.debug "< #{str}"
        elsif /\APING :/.match? str
          logger.debug "< #{str}"
        else
          logger.info "< #{str}"
        end
        break if /\AERROR :Closing Link: /.match? str

        # if str[/^:\S+ 433 * #{Regexp.escape bot_name} :Nickname is already in use\.$/]
        #   socket_send.call "NICK #{bot_name + "_"}"
        #   next
        # end

        # next socket.send("JOIN #{$2}"+"\n"),0 if str[/^:(.+?)!\S+ KICK (\S+) #{Regexp.escape bot_name} /i]
        case str
          when /\A:[a-z.]+ 001 #{Regexp.escape bot_name} :Welcome to the #{Regexp.escape welcome001} #{Regexp.escape bot_name}\z/
            # we join only when we are sure we are on the correct server
            # TODO: maybe abort if the server is wrong?
            next socket_send.call "JOIN #{channels.join ","}"

          when /\A:tmi.twitch.tv 001 #{Regexp.escape bot_name} :Welcome, GLHF!\z/
            socket_send.call "JOIN #{channels.join ","}"
            socket_send.call "CAP REQ :twitch.tv/membership twitch.tv/tags twitch.tv/commands"
            next
          when /\A:NickServ!NickServ@services\. NOTICE #{Regexp.escape bot_name} :This nickname is registered. Please choose a different nickname, or identify via \x02\/msg NickServ identify <password>\x02\.\z/,
               /\A:NickServ!NickServ@services\.libera\.chat NOTICE #{Regexp.escape bot_name} :This nickname is registered. Please choose a different nickname, or identify via \x02\/msg NickServ IDENTIFY #{Regexp.escape bot_name} <password>\x02\z/
            abort "no password" unless password
            logger.info "password"
            next socket.send "PRIVMSG NickServ :identify #{bot_name} #{password.strip}\n", 0
          # when /\A:[a-z]+\.libera\.chat CAP \* LS :/
          #   next socket_send "CAP REQ :sasl" if $'.split.include? "sasl"
          when /\A:[a-z]+\.libera\.chat CAP \* ACK :sasl\z/
            next socket_send.call "AUTHENTICATE PLAIN"
          when /\AAUTHENTICATE \+\z/
            logger.info "password"
            next socket.send "AUTHENTICATE #{Base64.strict_encode64 "\0#{identity || bot_name}\0#{password}"}\n", 0
          when /\A:[a-z]+\.libera\.chat 903 #{bot_name} :SASL authentication successful\z/
            next socket_send.call "CAP END"

          when /\APING :/
            next socket.send "PONG :#{$'}\n", 0   # Quakenet uses timestamp, Freenode and Twitch use server name
          when /\A:([^!]+)!\S+ PRIVMSG #{Regexp.escape bot_name} :\x01VERSION\x01\z/
            next socket_send.call "NOTICE #{$1} :\x01VERSION name 0.0.0\x01"
          # when /^:([^!]+)!\S+ PRIVMSG #{Regexp.escape bot_name} :\001PING (\d+)\001$/
          #   socket_send.call "NOTICE",$1,"\001PING #{rand 10000000000}\001"
          # when /^:([^!]+)!\S+ PRIVMSG #{Regexp.escape bot_name} :\001TIME\001$/
          #   socket_send.call "NOTICE",$1,"\001TIME 6:06:06, 6 Jun 06\001"
          when /\A#{'\S+ ' if tags}:(?<who>[^!]+)!\S+ PRIVMSG (?<where>\S+) :(?<what>.+)/
            next( if processors.empty?
              self.queue.push [master_name, "nothing to reload"]
            else
              processors.each do |processor|
                self.queue.push [master_name, "reloading #{processor}"]
                load File.absolute_path processor
              end
            end ) if $~.named_captures == {"who"=>master_name, "where"=>bot_name, "what"=>"#{masterword.strip} reload"}
        end

        begin
          yield str, ->(where, what){ self.queue.push [where, what] }
        rescue => e
          puts e.full_message
          self.queue.push [master_name, "yield error: #{e}"]
        end

      rescue => e
        puts e.full_message
        case e
        when Errno::ECONNRESET, Errno::ECONNABORTED, Errno::ETIMEDOUT, Errno::EPIPE
          sleep 5
          break
        else
          self.queue.push [master_name, "unhandled error: #{e}"]
          sleep 5
        end
      end

    end

  end
end

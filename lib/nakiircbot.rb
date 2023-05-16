module NakiIRCBot
  require "base64"

  @queue = Queue.new
  def self.start server, port, bot_name, master_name, welcome001, *channels, identity: nil, password: nil, masterword: nil, processors: [], tags: false
    # @@channels.replace channels.dup

    abort "matching bot_name and master_name may cause infinite recursion" if bot_name == master_name
    require "fileutils"
    FileUtils.mkdir_p "logs"
    require "logger"
    # TODO: check how I've implemented the logger in trovobot
    original_formatter = Logger::Formatter.new
    logger = Logger.new "logs/txt", "daily",
                        progname: bot_name, datetime_format: "%y%m%d %H%M%S",
                        formatter: lambda{ |severity, datetime, progname, msg|
      puts "#{datetime.strftime "%H%M%S"} #{severity.to_s[0]} #{progname} #{msg.scrub.inspect[1..-2]}"
      original_formatter.call severity, datetime, progname, Base64.strict_encode64(msg)
      # TODO: maybe encode the whole string for a case of invalid progname?
    }
    logger.level = Logger::WARN
    logger.level = ENV["LOGLEVEL_#{name}"].to_sym if ENV.include? "LOGLEVEL_#{name}"
    puts "#{name} logger.level = #{logger.level}"

    # https://stackoverflow.com/a/49476047/322020

    require "socket"
    # require "io/wait"
    socket = Module.new do
      @logger = logger
      @server = server
      @port = port

      @socket = nil
      def self.rescue_socket
        yield
      rescue SocketError, Errno::ENETDOWN, Errno::ENETUNREACH
        @socket = nil
        @logger.warn "exception: #{$!}, waiting 5 sec"
        sleep 5
        retry
      end
      private_class_method :rescue_socket
      def self.socket
        @socket ||= rescue_socket do
          @logger.warn "reconnect"
          TCPSocket.new(@server, @port)#.tap{ queue_thread.run }
        end
      end
      private_class_method :socket
      @buffer = ""
      def self.read
        until i = @buffer.index(?\n)
          @buffer.concat( rescue_socket do
            return unless select [socket], nil, nil, 1
            @socket.read(@socket.nread).tap{ |_| raise SocketError, "empty read" if _.empty? }
          end )
        end
        @buffer.slice!(0..i).chomp
      end
      def self.write str
        socket.send str + "\n", 0
      end
      def self.log str
        @logger.warn "> #{str}"
        write str
      end
    end
    prev_privmsg_time = Time.now
    queue_thread = Thread.new do
      Thread.current.abort_on_exception = true
      # Thread.stop
      loop do
        sleep [prev_privmsg_time + 5 - Time.now, 0].max
        addr, msg = @queue.pop
        fail "I should not PRIVMSG myself" if bot_name == addr = addr.codepoints.pack("U*").tr("\x00\x0A\x0D", "")
        privmsg = "PRIVMSG #{addr} :#{msg.to_s.codepoints.pack("U*").chomp[/^(\x01*)(.*)/m,2].gsub("\x00", "[NUL]").gsub("\x0A", "[LF]").gsub("\x0D", "[CR]")}"
        privmsg[-4..-1] = "..." until privmsg.bytesize <= 475
        prev_privmsg_time = Time.now
        socket.log privmsg
      end
    end

    # https://en.wikipedia.org/wiki/List_of_Internet_Relay_Chat_commands
    loop do
      # socket_log.call "CAP LS"
      # https://ircv3.net/specs/extensions/sasl-3.1.html
      socket.log "CAP REQ :sasl" if password
      socket.write "PASS #{password.strip}"   # https://dev.twitch.tv/docs/irc/authenticate-bot/
      socket.log "NICK #{bot_name}"
      socket.log "USER #{bot_name} #{bot_name} #{bot_name} #{bot_name}" #unless twitch

      @queue.clear
      prev_socket_time = prev_privmsg_time = Time.now
      loop do
        unless socket_str = socket.read
          break if Time.now - prev_socket_time > 300
          next
        end
        prev_socket_time = Time.now
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
        #   socket_log.call "NICK #{bot_name + "_"}"
        #   next
        # end

        # next socket.send("JOIN #{$2}"+"\n"),0 if str[/^:(.+?)!\S+ KICK (\S+) #{Regexp.escape bot_name} /i]
        case str
          when /\A:[a-z.]+ 001 #{Regexp.escape bot_name} :Welcome to the #{Regexp.escape welcome001} #{Regexp.escape bot_name}\z/
            # we join only when we are sure we are on the correct server
            # TODO: maybe abort if the server is wrong?
            next socket.log "JOIN #{channels.join ","}"

          when /\A:tmi.twitch.tv 001 #{Regexp.escape bot_name} :Welcome, GLHF!\z/
            socket.log "JOIN #{channels.join ","}"
            socket.log "CAP REQ :twitch.tv/membership twitch.tv/tags twitch.tv/commands"
            tags = true
            next
          when /\A:NickServ!NickServ@services\. NOTICE #{Regexp.escape bot_name} :This nickname is registered. Please choose a different nickname, or identify via \x02\/msg NickServ identify <password>\x02\.\z/,
               /\A:NickServ!NickServ@services\.libera\.chat NOTICE #{Regexp.escape bot_name} :This nickname is registered. Please choose a different nickname, or identify via \x02\/msg NickServ IDENTIFY #{Regexp.escape bot_name} <password>\x02\z/
            abort "no password" unless password
            logger.warn "password"
            next socket.write "PRIVMSG NickServ :identify #{bot_name} #{password.strip}"
          # when /\A:[a-z]+\.libera\.chat CAP \* LS :/
          #   next socket_log "CAP REQ :sasl" if $'.split.include? "sasl"
          when /\A:[a-z]+\.libera\.chat CAP \* ACK :sasl\z/
            next socket.log "AUTHENTICATE PLAIN"
          when /\AAUTHENTICATE \+\z/
            logger.warn "password"
            next socket.write "AUTHENTICATE #{Base64.strict_encode64 "\0#{identity || bot_name}\0#{password}"}"
          when /\A:[a-z]+\.libera\.chat 903 #{bot_name} :SASL authentication successful\z/
            next socket.log "CAP END"

          when /\APING :/
            next socket.write "PONG :#{$'}"   # Quakenet uses timestamp, Freenode and Twitch use server name
          when /\A:([^!]+)!\S+ PRIVMSG #{Regexp.escape bot_name} :\x01VERSION\x01\z/
            next socket.log "NOTICE #{$1} :\x01VERSION name 0.0.0\x01"
          # when /^:([^!]+)!\S+ PRIVMSG #{Regexp.escape bot_name} :\001PING (\d+)\001$/
          #   socket_log.call "NOTICE",$1,"\001PING #{rand 10000000000}\001"
          # when /^:([^!]+)!\S+ PRIVMSG #{Regexp.escape bot_name} :\001TIME\001$/
          #   socket_log.call "NOTICE",$1,"\001TIME 6:06:06, 6 Jun 06\001"
        end

        begin
          yield str,
            ->(where, what){ @queue.push [where, what] },
            ->(new_password){ password.replace new_password; socket.instance_variable_set :@socket, nil },
            */\A#{'\S+ ' if tags}:(?<who>[^!]+)!\S+ PRIVMSG (?<where>\S+) :(?<what>.+)/.match(str).to_a.drop(1).tap{ |who, where, what|
              logger.warn "#{where} <#{who}> #{what}" if what
            }
        rescue
          puts $!.full_message
          @queue.push ["##{bot_name}", "error: #{$!}, #{$!.backtrace.first}"]
        end

      rescue
        puts $!.full_message
          sleep 5
        raise
      end

    end

  end

  module Common
    def self.ping add_to_queue, what
      return add_to_queue.call what[1..-1].tr "iI", "oO" if "\\ping" == what.downcase
      return add_to_queue.call what[1..-1].tr "иИ", "оO" if "\\пинг" == what.downcase
    end
  end

  def self.parse_log path, bot_name
    require "time"
    get_tags = lambda do |str|
      str[1..-1].split(?;).map do |pair|
        (a, b) = pair.split ?=
        fail if a.empty?
        [a, b]
      end.to_h
    end
    File.new(path).each(chomp: true).drop(1).map do |line|
      case line
      when /\AD, /
      when /\A[IW], \[(\S+) #\d+\]  (?:INFO|WARN) -- #{bot_name}: (.+)\z/
        _ = Base64.decode64($2).force_encoding "utf-8"
        [
          DateTime.parse($1).to_time,
          *case _
          when /\A> /,
               "< :tmi.twitch.tv 002 #{bot_name} :Your host is tmi.twitch.tv",
               "< :tmi.twitch.tv 003 #{bot_name} :This server is rather new",
               "< :tmi.twitch.tv 004 #{bot_name} :-",
               "< :tmi.twitch.tv 375 #{bot_name} :-",
               "< :tmi.twitch.tv 376 #{bot_name} :>",
               /\A< :#{bot_name}!#{bot_name}@#{bot_name}\.tmi\.twitch\.tv JOIN #[a-z\d_]+\z/,
               /\A< :#{bot_name}\.tmi\.twitch\.tv 353 #{bot_name} /,
               /\A< :#{bot_name}\.tmi\.twitch\.tv 366 #{bot_name} /,
               "< :tmi.twitch.tv CAP * ACK :twitch.tv/membership twitch.tv/tags twitch.tv/commands",
               "< :tmi.twitch.tv CAP * NAK :sasl",
               "< :tmi.twitch.tv NOTICE * :Improperly formatted auth",
               "< :tmi.twitch.tv RECONNECT"
          when /\A< (\S+) :tmi\.twitch\.tv USERSTATE ##{bot_name}\z/ # wtf?
          when "reconnect",
               "< :tmi.twitch.tv 001 #{bot_name} :Welcome, GLHF!"
            [nil, "RECONNECT"]
          when /\A< :([^\s!]+)!\1@\1\.tmi\.twitch\.tv (JOIN|PART) #([a-z\d_]+)\z/
            [$3, $2, $1]
          when /\A< (?:\S+ )?:([^\s!]+)!\1@\1\.tmi\.twitch\.tv PRIVMSG #([a-z\d_]+) :((?:\S.*)?\S)\z/
            [$2, "PRIVMSG", $1, $3]
          when /\A< (\S+) :tmi\.twitch\.tv CLEARMSG #([a-z\d_]+) :((?:\S.*)?\S)\z/
            [$2, "CLEARMSG", get_tags[$1].fetch("login"), $3]
          when /\A< (\S+) :tmi\.twitch\.tv CLEARCHAT #([a-z\d_]+) :([^\s!]+)\z/
            [$2, "CLEARCHAT", $3, get_tags[$1].fetch("target-user-id")]
          when /\A< @emote-only=0;room-id=\d+ :tmi\.twitch\.tv ROOMSTATE #([a-z\d_]+)\z/
            [$1, "ROOMSTATE EMOTEONLY 0"]
          when /\A< @emote-only=1;room-id=\d+ :tmi\.twitch\.tv ROOMSTATE #([a-z\d_]+)\z/
            [$1, "ROOMSTATE EMOTEONLY 1"]
          when /\A< @msg-id=emote_only_off :tmi\.twitch\.tv NOTICE #([a-z\d_]+) :This room is no longer in emote-only mode\.\z/
            [$1, "EMOTE_ONLY_OFF"]
          when /\A< @msg-id=emote_only_on :tmi\.twitch\.tv NOTICE #([a-z\d_]+) :This room is now in emote-only mode\.\z/
            [$1, "EMOTE_ONLY_ON"]
          when /\A< @followers-only=-1;room-id=\d+ :tmi\.twitch\.tv ROOMSTATE #([a-z\d_]+)\z/
            [$1, "ROOMSTATE FOLLOWERSONLY 0"]
          when /\A< @msg-id=followers_off :tmi\.twitch\.tv NOTICE #([a-z\d_]+) :This room is no longer in followers-only mode\.\z/
            [$1, "FOLLOWERS_ONLY_OFF"]
          when /\A< :tmi\.twitch\.tv HOSTTARGET #([a-z\d_]+) :(\S+) (\d+)\z/
            next if "-" == $2 # wtf?
            fail unless $2 == $2.downcase
            [$1, "HOST", $2, $3.to_i]
          when /\A< @msg-id=host_target_went_offline :tmi\.twitch\.tv NOTICE #([a-z\d_]+) :(\S+) has gone offline\. Exiting host mode\.\z/
            fail unless $2 == $2.downcase
            [$1, "HOST_TARGET_WENT_OFFLINE", $2]
          when /\A< @msg-id=host_on :tmi\.twitch\.tv NOTICE #([a-z\d_]+) :Now hosting (\S+)\.\z/
            [$1, "NOTICE HOST", $2]
          when /\A< (\S+) :tmi\.twitch\.tv USERNOTICE #([a-z\d_]+)(?: :((?:\S.*)?\S))?\z/
            tags = get_tags[$1]
            fail unless tags.fetch("display-name").downcase == tags.fetch("login")
            [
              $2,
              tags["msg-id"].upcase,
              *case tags.fetch "msg-id"
              when "raid"
                fail if $3
                [tags.fetch("display-name"), tags.fetch("msg-param-viewerCount").to_i.tap{ |_| fail unless _ > 0 }]
              when "resub"
                [tags.fetch("display-name"), *$3]
              when "sub"
                fail if $3
                [tags.fetch("display-name")]
              when "submysterygift"
                # fail unless tags["msg-param-mass-gift-count"] == "1"
                # fail unless tags["msg-param-sender-count"] == "1"
                fail if $3
                [tags.fetch("display-name"), tags.fetch("msg-param-mass-gift-count")]
              when "subgift"
                fail unless "1" == tags.fetch("msg-param-gift-months")
                # fail unless tags["msg-param-months"] == "1"
                fail if $3
                [tags.fetch("display-name")]
              when "bitsbadgetier"
                fail unless $3
                [tags.fetch("display-name")]
              when "primepaidupgrade"
                fail if $3
                [tags.fetch("display-name")]
              when "viewermilestone"
                fail if $3
                [tags.fetch("display-name")]
              else
                fail "unknown USERNOTICE: #{[tags["msg-id"], _, $3].inspect}"
              end
            ]
          else
            fail "bad log line: #{_.inspect}"
          end
        ]
      else
        fail line.inspect
      end
    end.compact.tap{ |_| fail unless 1 == _.map(&:first).map(&:day).uniq.size }
  end
end

remote = []
reload = lambda do
  require "open-uri"
  require "yaml"
  remote.replace YAML.load open "https://gist.githubusercontent.com/nakilon/92d5b22935f21b5e248b713057e851a6/raw/remote.yaml", &:read
end.tap &:call

require "nakiircbot"
nickname = ENV["TEST"] ? "velik2" : "velik"
NakiIRCBot.start "irc.libera.chat", "6666", nickname, "nakilon", "Libera.Chat Internet Relay Chat Network", (ENV["TEST"] ? "##nakilon" : "#esolangs"),
    password: (File.read("password") unless ENV["TEST"]), masterword: File.read("masterword") do |str, add_to_queue|

  next unless /\A:(?<who>[^\s!]+)!\S+ PRIVMSG (?<where>\S+) :(?<what>.+)/ =~ str
  add_to_queue.call "nakilon", str if where == nickname && who != "nakilon"

  dest = where == nickname ? who : where
  next add_to_queue.call dest, what.tr("iI", "oO") if what.downcase == "ping"
  next add_to_queue.call dest, what.tr("иИ", "оO") if what.downcase == "пинг"

  threaded = lambda do |&block|
    Thread.new do
      block.call
    rescue => e
      puts e.full_message
      add_to_queue.call "nakilon", e
      add_to_queue.call dest, "thread error" unless dest == "nakilon"
    end
  end

  case what
  when /\A\\help\s*\z/
    add_to_queue.call dest, "available commands: #{remote.map &:first}; usage help: \\help <cmd>"
  when /\A\\help\s+(\S+)/
    add_to_queue.call dest, (
      if (_, _, help = remote.assoc($1))
        help
      else
        "unknown command #{$1.inspect}"
      end
    )
  when "\\reload remote"
    threaded.call do
      reload.call
      add_to_queue.call dest, "remote execution commands loaded: #{remote.map &:first}"
    end
  when /\A\\(\S+) (.+)/
    cmd, input = $1, $2
  remote.each do |remote_cmd, function,|
    break( threaded.call do
      args, kwargs = (ENV["LOCALHOST"] ? [["localhost", 8080], {}] : [["us-central1-nakilonpro.cloudfunctions.net", 443], use_ssl: true])
      require "net/http"
      Net::HTTP.start(*args, **kwargs) do |http|
        require "base64"
        response = http.request_post "/#{function}", Base64.strict_encode64(input), {Authorization: "bearer #{`gcloud auth print-identity-token #{ENV["SERVICE_ACCOUNT"]}`}"}
        fail response.inspect unless response.is_a? Net::HTTPOK
        add_to_queue.call dest, response.body
      end
    end) if cmd == remote_cmd
  end
  end
end

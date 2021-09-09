STDOUT.sync = true  # kludge for docker logs

remote = []
reload = lambda do
  require "open-uri"
  require "yaml"
  remote.replace YAML.load open "https://gist.githubusercontent.com/nakilon/92d5b22935f21b5e248b713057e851a6/raw/remote.yaml", &:read
end.tap &:call

# for [wiki ...]  # TODO: get rid in favor of Infoboxer?
require "mediawiki-butt"
esowiki = MediaWiki::Butt.new "https://esolangs.org/w/api.php"
# for \wiki and \esowiki
require "infoboxer"

# we prepend space to reply only if reply can be arbitrary (forged by invoking IRC user, like \rasel or \wiki)

require "nakiircbot"
nickname = ENV["VELIK_NICKNAME"] || "velik"
NakiIRCBot.start (ENV["VELIK_SERVER"] || "irc.libera.chat"), "6666", nickname, "nakilon", "Libera.Chat Internet Relay Chat Network", (ENV["VELIK_CHANNEL"] || "#esolangs"),
    password: (File.read("password") if nickname == "velik"), masterword: File.read("masterword") do |str, add_to_queue|

  next unless /\A:(?<who>[^\s!]+)!\S+ PRIVMSG (?<dest>\S+) :(?<what>.+)/ =~ str
  add_to_queue.call "nakilon", str if dest == nickname && who != "nakilon"
  dest = who if dest == nickname

  next add_to_queue.call dest, what.tr("iI", "oO") if what.downcase == "ping"
  next add_to_queue.call dest, what.tr("иИ", "оO") if what.downcase == "пинг"

  # for remote and slow replies
  threaded = lambda do |&block|
    # note that it loses the access to $1, $2... so you copy their values before the call
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
    add_to_queue.call dest, "available commands: #{%w{ wiki esowiki } + remote.map(&:first)}; usage help: \\help <cmd>"
  when /\A\\help\s+(\S+)/
    add_to_queue.call dest, (
      if (*_, help = remote.assoc($1))
        help
      elsif $1 == "wiki"
        "\\wiki <wikipedia article or search query>"
      elsif $1 == "esowiki"
        "\\esowiki <esolang wiki article or search query>"
      else
        "unknown command #{$1.inspect}"
      end
    )
  when "\\reload remote"
    threaded.call do
      reload.call
      add_to_queue.call dest, "remote execution commands loaded: #{remote.map &:first}"
    end
  when /\A\\wiki (.+)/
    query = $1
    threaded.call do
      wikipedia = Infoboxer.wp
      unless page = wikipedia.get(query){ |_| _.prop :pageterms } || wikipedia.search(query, limit: 1){ |_| _.prop :pageterms }.first
        add_to_queue.call dest, "nothing was found"
      else
        add_to_queue.call dest, " #{
          if about = page.templates(name: "About").first
            _, _, alt, *_ = about.unwrap.map(&:text)
            # TODO: propose the (disambiguation) page
            "(see also: #{alt}) " if alt
          end
        }#{
          page.source.fetch("terms").fetch_values("label", "description").join(" -- ").tap do |reply|
            reply[-4..-1] = "..." until "#{reply} #{page.url}".bytesize <= 450
          end
        } #{page.url}"
      end
    end
  when /\A\\esowiki (.+)/
    query = $1
    threaded.call do
      esolangs = Infoboxer.wiki "https://esolangs.org/w/api.php"
      unless page = esolangs.get(query) || esolangs.search(query, limit: 1).first
        add_to_queue.call dest, "nothing was found"
      else
        add_to_queue.call dest, " #{
          page.paragraphs.map do |par|
            par if par.children.any?{ |_| _.is_a?(Infoboxer::Tree::Text) && !_.to_s.empty? }
          end.find(&:itself).text.strip.tap do |reply|
            reply[-4..-1] = "..." until "#{reply} #{page.url}".bytesize <= 450
          end
        } #{page.url}"
      end
    end
  when /\A\\(\S+) (.+)/
    cmd, input = $1, $2
    remote.each do |remote_cmd, function, encoding, |
      break( threaded.call do
        args, kwargs = (ENV["LOCALHOST"] ? [["localhost", 8080], {}] : [["us-central1-nakilonpro.cloudfunctions.net", 443], use_ssl: true])
        require "net/http"
        Net::HTTP.start(*args, **kwargs) do |http|
          require "json"
          response = http.request_post "/#{function}", JSON.dump(input), {Authorization: "bearer #{`gcloud auth print-identity-token #{ENV["SERVICE_ACCOUNT"]}`}"}
          fail response.inspect unless response.is_a? Net::HTTPOK
          add_to_queue.call dest, " " + response.body.force_encoding(encoding)
        end
      end) if cmd == remote_cmd
    end
  else
    wikis = what.scan(/\[\s*wiki\s+(\S.*?)\s*\]/i)
    unless wikis.empty?
      threaded.call do
        results = wikis.map do |article,|
          result = esowiki.get_search_results article
          result = esowiki.get_search_text_results article if result.empty?
          "https:" + URI.escape(URI.escape(esowiki.get_article_path result.first), "?") unless result.empty?
        end.compact
        add_to_queue.call dest, results.uniq.join(" ") unless results.empty?
      end
    end
  end
end

STDOUT.sync = true  # kludge for docker logs

require "open-uri"
remote = []
reload = lambda do
  require "yaml"
  remote.replace YAML.load open "https://gist.githubusercontent.com/nakilon/92d5b22935f21b5e248b713057e851a6/raw/remote.yaml", &:read
end
require "timeout"
Timeout.timeout(2){ reload.call }

require "infoboxer"
esolangs = Infoboxer.wiki "https://esolangs.org/w/api.php"
page_summary_450 = lambda do |page|
  page.paragraphs.map do |par|
    par if par.children.any?{ |_| _.is_a?(Infoboxer::Tree::Text) && !_.to_s.empty? }
  end.find(&:itself).text.strip.gsub(/\n+/, " ").tap do |reply|
    reply[-4..-1] = "..." until "#{reply} #{page.url}".bytesize <= 450
  end
end
get_rescue_nil = lambda do |wiki, query, &block|  # Infoboxer raises RuntimeError
  wiki.get query, &block
rescue RuntimeError
end


# we prepend space to reply only if reply can be arbitrary (forged by invoking IRC user, like \rasel or \wiki)

require "nakiircbot"
nickname = ENV["VELIK_NICKNAME"] || "velik"


require "google/cloud/pubsub"
Google::Cloud::Pubsub.new.subscription("velik-sub").listen do |received_message|
  NakiIRCBot.queue.push JSON.load(received_message.data).values_at("addr", "msg")
  received_message.acknowledge!
rescue => e
  puts e.full_message
  NakiIRCBot.queue.push "nakilon", e
  raise
end.start


require "nethttputils"
require "json/pure"

NakiIRCBot.start (ENV["VELIK_SERVER"] || "irc.libera.chat"), "6666", nickname, "nakilon", "Libera.Chat Internet Relay Chat Network",
    *(ENV["VELIK_CHANNEL"] || %w{ ##nakilon #ruby-ru #ruby-offtopic #programming-ru #botters-test #bots }),
    password: (File.read("password") if nickname == "velik" || nickname == "velik2"), identity: "velik", masterword: File.read("masterword") do |str, add_to_queue|

  next unless /\A:(?<who>[^\s!]+)!\S+ PRIVMSG (?<dest>\S+) :(?<what>.+)/ =~ str
  add_to_queue.call "nakilon", str if dest == nickname && who != "nakilon"

  # for remote and slow replies
  threaded = lambda do |&block|
    # note that it loses the access to $1, $2... so you copy their values before the call
    Thread.new do
      block.call
    rescue StandardError, WebMock::NetConnectNotAllowedError => e
      puts e.full_message
      add_to_queue.call "nakilon", e
      add_to_queue.call dest, "thread error" unless dest == "nakilon"
    end
  end

  threaded.call do
    NetHTTPUtils.request_data "https://api.telegram.org/bot#{File.read "tg.token"}/sendMessage", :post, form: {chat_id: "@ruby_not_rails", text: "<#{who}> #{what}", disable_notification: true}
  end if dest == "#ruby-ru"

  dest = who if dest == nickname
  next if [
    %w{ #esolangs esolangs },
  ].include? [dest, who]

  next add_to_queue.call dest, what.tr("iI", "oO") if what.downcase == "ping"
  next add_to_queue.call dest, what.tr("иИ", "оO") if what.downcase == "пинг"

  case what
  when /\A\\help\s*\z/
    add_to_queue.call dest, "available commands: #{%w{ wiki wp wa } + remote.map(&:first)}; usage help: \\help <cmd>"
  when /\A\\help\s+(\S+)/
    add_to_queue.call dest, (
      if (*_, help = remote.assoc($1))
        help
      elsif $1 == "wiki" ; "\\wiki <Esolang wiki article or search query>"
      elsif $1 == "wp" ; "\\wp <Wikipedia article or search query>; \\wp-<lang> <query> (for <lang>.wikipedia.org)"
      elsif $1 == "wa" ; "\\wa <Wolfram Alpha query>; \\was <query> (for shorter result)"
      else
        "unknown command #{$1.inspect}"
      end
    )
  when "\\reload remote"
    threaded.call do
      reload.call
      add_to_queue.call dest, "remote execution commands loaded: #{remote.map &:first}"
    end
  when /\A\\wp(?:-([a-z]+(?:-[a-z]+)?))? (.+)/
    lang, query = $1, $2
    threaded.call do
      # https://en.wikipedia.org/wiki/List_of_Wikipedias
      wikipedia = Infoboxer.wikipedia lang || "en"
      unless page = get_rescue_nil.call(wikipedia, query){ |_| _.prop :pageterms } ||
                    wikipedia.search(query, limit: 1){ |_| _.prop(:pageterms) }.first ||
                    wikipedia.search(query, limit: 1){ |_| _.prop(:pageterms).what(:text) }.first
        add_to_queue.call dest, "nothing was found"
      else
        add_to_queue.call dest, " #{
          if about = page.templates(name: "About").first
            _, _, alt, *_ = about.unwrap.map(&:text)
            # TODO: propose the (disambiguation) page
            "(see also: #{alt}) " if alt
          end
        }#{
          label, description = page.source.fetch("terms").values_at("label", "description")
          if description
            fail unless description.size == 1
            fail unless label && label.size == 1
            [label, description].join(" -- ").tap do |reply|
              reply[-4..-1] = "..." until "#{reply} #{page.url}".bytesize <= 450
            end
          else
            if short = page.templates(name: "Short description").first
              short.unwrap.text
            else
              page_summary_450.call page
            end
          end
        } #{page.url}"
      end
    end
  when /\A\\wiki (.+)/
    query = $1
    threaded.call do
      unless page = get_rescue_nil.call(esolangs, query) ||
                    esolangs.search(query, limit: 1).first ||
                    esolangs.search(query, limit: 1){ |_| _.what :text }.first
        add_to_queue.call dest, "nothing was found"
      else
        add_to_queue.call dest, " #{page_summary_450.call page} #{page.url}"
      end
    end
  when /\A\\wa(s)? (.+)/  # https://products.wolframalpha.com/docs/WolframAlpha-API-Reference.pdf
    short, query = $1, $2.strip
    link = URI("http://api.wolframalpha.com/v2/query").tap do |uri|
      uri.query = URI.encode_www_form({input: query, format: :plaintext, appid: File.read("wa.key.txt")})
    end
    require "oga"
    require "nakischema"
    threaded.call do
      xml = Oga.parse_xml open link, &:read
      Nakischema.validate_oga_xml xml, {
        exact: {
          "queryresult" => [[ {
            attr_req: {"success": %w{ true false }, "error": "false", "inputstring": query.chomp(??)},
            assertions: [->n,_{ n.at_xpath("pod").nil? || n.at_xpath("pod")["id"] == "Input" }],
            children: {
              ".//*[@error='true']" => [[]],
              "pod[@primary='true']" => {size: 0..3, each: {children: {"subpod" => {size: 1..9, each: {attr_req: {"title" => /\A([A-Z][a-z]+)?\z/}, children: {"plaintext" => [[{}]]}}}}}},
              ".//pod" => {each: {
                attr_req: {"id": /\A[A-Z]*(A|[A-Z][a-z]+)+((:([A-Z]+[a-z]+)+)+|=0\.| \(time\))?\z/, "scanner": /\A([A-Z][a-z]*)+\z/},
                children: {
                  "expressiontypes" => [[ {
                    assertions: [->n,_{ n["count"].to_i == n.xpath("*").size }],
                    exact: {"expressiontype" => {size: 1..15, each: {attr_exact: {"name" => /\A(Default|Grid|1DMathPlot|2DMathPlot|TimeSeriesPlot|TimelinePlot)\z/}}}},
                  } ]],
                },
              } },
            },
          } ]],
        },
      }
      pods = xml.xpath("*/pod").drop(1).map do |pod|
        [
          pod["primary"] == "true" ? 0 : 1,
          if [
            *%w{ Plot },   # Mathematics
            # *%w{ UnitInformation },
          ].include? pod["scanner"]  # bad
          elsif [ # include
                  *%w{ Numeric NumberLine MathematicalFunctionData ContinuedFraction Simplification Integer Rational Factor Integral Series FunctionProperties Plotter NumberLine Reduce ODE },  # Mathematics
                  *%w{ Data },  # Chemistry
                  *%w{ Identity Date },  # Society & Culture
                  *%w{ Age Unit },  # Everyday Life
                  *%w{ Arithmetic UnitInformation StringEncodings WordPuzzle RandomLookup NumberComparison Character ComputerKeyboard Geometry PlanetaryAstronomy },
                ].include?(pod["scanner"])
            if pod["primary"] == "true" || ![   # exclude
              *%w{ PlotsOfSampleIndividualSolutions SampleSolutionFamily }, # ODE
              *%w{ ReactionStructures:ChemicalReactionData }, # Data (Chemistry)
              *%w{ Illustration }, # Arithmetic
              *%w{ ComputerKeyboardsContainingLetter VisualRepresentation },
            ].include?(pod["id"])
              subpods = pod.xpath("subpod").
                map{ |_| [("#{_["title"]}: " unless _["title"].empty?), _.at_xpath("plaintext").text] }.
                zip(pod.xpath(".//expressiontype").map{ |_| _["name"] }).
                reject{ |(title, text), type| !type || text.empty? || %w{ Grid 1DMathPlot 2DMathPlot TimeSeriesPlot TimelinePlot }.include?(type) }
              "#{pod["title"]}: #{
                CGI.unescapeHTML(subpods.size == 1 ? subpods.first.first.last : subpods.map(&:first).map(&:join).join(", ")).tr("\n", " ")
              }" unless subpods.empty?
            end
          else
            "(#{nickname}: unsupported scanner #{pod["scanner"]})"
          end
        ]
      end.select(&:last)
      add_to_queue.call dest,
        xml.at_xpath("queryresult")["success"] == "false" ?
          "not clear what you mean" :
          pods.empty? ?
            "results are not printable" :
            " #{pods.sort_by{ |primary, text| [primary, primary * text.size] }.reject.with_index{ |(primary, _), i| short && primary > 0 && i > 0 }.map(&:last).join " | "}"
    end
  when /\A\\(\S+) (.+)/
    cmd, input = $1, $2
    remote.each do |remote_cmd, function, encoding, |
      break( threaded.call do
        args, kwargs = (ENV["LOCALHOST"] ? [["localhost", 8080], {}] : [["us-central1-nakilonpro.cloudfunctions.net", 443], use_ssl: true])
        Net::HTTP.start(*args, **kwargs) do |http|
          response = http.request_post "/#{function}", JSON.dump(input), {Authorization: "bearer #{`gcloud auth print-identity-token #{ENV["SERVICE_ACCOUNT"]}`}"}
          fail response.inspect unless response.is_a? Net::HTTPOK
          add_to_queue.call dest, " " + response.body.force_encoding(encoding)
        end
      end) if cmd == remote_cmd
    end
  when /\A#{nickname}[^a-zA-Z0-9_-] *(\S.*)/
    input = $1
    threaded.call do
      args, kwargs = (ENV["LOCALHOST"] ? [["localhost", 8080], {}] : [["us-central1-nakilonpro.cloudfunctions.net", 443], use_ssl: true])
      Net::HTTP.start(*args, **kwargs) do |http|
        response = http.request_post "/chat-#{input[/[а-яё]/i] ? "russian" : "english"}", JSON.dump(input), {Authorization: "bearer #{`gcloud auth print-identity-token #{ENV["SERVICE_ACCOUNT"]}`}"}
        fail response.inspect unless response.is_a? Net::HTTPOK
        add_to_queue.call dest, " " + response.body.force_encoding("utf-8") unless response.body.empty?
      end
    end
  else
    wikis = what.scan(/\[\[([^\]\[]+)\]\]/i)
    threaded.call do
      results = wikis.map do |query,|
        get_rescue_nil.call(esolangs, query) || begin
          esolangs.search(query, limit: 1).last
        rescue MediaWiktory::Wikipedia::Response::Error
        end
      end.compact
      add_to_queue.call dest, results.map(&:url).uniq.join(" ") unless results.empty?
    end unless wikis.empty?   # just to not create Thread for no reason
    dup = what.dup
    links = dup.enum_for(:scan, URI.regexp(%w{ http https })).map{ [$`.size, $&] }.map{ |a, b| dup[a, b.size] = " " * b.size; b }
    threaded.call do
      add_to_queue.call dest, ((
        links.map do |link|
          if %w{ reddit com } == URI(link).host.split(?.).last(2)

            # took from directlink gem, TODO: define it as a method there?
            id = link[/\Ahttps:\/\/www\.reddit\.com\/gallery\/([0-9a-z]{5,6})\z/, 1] ||
                 URI(link).path[/\A(?:\/r\/[0-9a-zA-Z_]+)?(?:\/comments|\/duplicates)?\/([0-9a-z]{5,6})(?:\/|\z)/, 1] ||
                 fail("bad Reddit URL")
            retry_on_json_parseerror = lambda do |&b|
              t = 1
              begin
                b.call
              rescue JSON::ParserError => e
                fail "stupid Reddit can't return JSON" if 60 < t *= 2
                sleep t
                retry
              end
            end
            require "reddit_bot"
            RedditBot.logger.level = Logger::ERROR
            json = retry_on_json_parseerror.call{ RedditBot::Bot.new(YAML.load_file "reddit.yaml").json :get, "/by_id/t3_#{id}" }
            "#{json["data"]["children"][0]["data"]["subreddit_name_prefixed"]}: \""\
            "#{json["data"]["children"][0]["data"]["title"]}\""
          else
            begin
              require "video_info"
              t = VideoInfo.new link
              "#{t.author}: \"#{t.title}\""
            rescue VideoInfo::UrlError
              require "metainspector"
              "\"#{MetaInspector.new(link).best_title}\""
            end
          end
        end.join ", "
      ))
    end unless dest != "##nakilon" || links.empty? || dup[/[a-z]/i]
  end
end

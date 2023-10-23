def smart_match query, array
  array.min_by do |_|
    a, b = [query, yield(_)].map{ |_| _.downcase.squeeze.split }
    [
      a.sum do |i|
        b[0] ||= ""
        k, dist = b.map.with_index{ |j, _| [_, DidYouMean::Levenshtein.distance(i, j)] }.min_by(&:last)
        b.delete_at k
        dist
      end,
      DidYouMean::Levenshtein.distance(a.join(" "), b.join(" "))
    ]
  end
end

require "nethttputils"
require "json"

def refresh
  puts "refreshing token"
  File.write "tokens.secret", NetHTTPUtils.request_data("https://id.twitch.tv/oauth2/token", :POST, form: {
    client_id: File.read("clientid.secret"),
    client_secret: File.read("secret.secret"),
    grant_type: "refresh_token",
    refresh_token: JSON.load(File.read("tokens.secret"))["refresh_token"]
  } )
end

module Common

  def self.request mtd, **form
    JSON.load begin
      NetHTTPUtils.request_data \
      "https://api.twitch.tv/helix/#{mtd}",
      form: form,
      header: {
        "Authorization" => "Bearer #{JSON.load(File.read("tokens.secret"))["access_token"]}",
        "client-id" => File.read("clientid.secret")
      }
    rescue NetHTTPUtils::Error
      fail unless '{"error":"Unauthorized","status":401,"message":"Invalid OAuth token"}' == $!.body
      refresh
      sleep 5
      retry
    end
  end
  private_class_method :request
  def self.login_to_id login
    request("users", "login" => login)["data"][0]["id"]
  end
  def self.clips where
    user_id = login_to_id(where[/\A#*(.+)/, 1])
  f = lambda do |cursor = nil|
    t = request("clips", broadcaster_id: user_id, first: 100, **(cursor ? { after: cursor } : {}))
    t["data"] + t["pagination"]["cursor"].then{ |_| _ ? f[_] : [] }
  end
    f.call
  end
  def self.clip where, query
    smart_match(query, clips(where).sort_by{ |_| -_["view_count"] }){ |_| _["title"] }.fetch("url", "no clips found")
  end

  def self.get_item_id query
    locale = JSON.load File.read "ru.json"
    all = JSON.load(File.read "items.json").each_with_object({}) do |(id, item), h|
      fail id unless id == item["_id"]
      next if "Node" == item["_type"]
      fail unless "Item" == item["_type"]
      next if "557596e64bdc2dc2118b4571" == item.fetch("_parent")   # Pockets
      next if "6050cac987d3f925bf016837" == item.fetch("_parent")   # SortingTable
      next if "566965d44bdc2d814c8b4571" == item.fetch("_parent")   # LootContainer
      next if "62f109593b54472778797866" == item.fetch("_parent")   # RandomLootContainer
      next if "566abbb64bdc2d144c8b457d" == item.fetch("_parent")   # Stash
      # we need items.json to filter out fake items
      # we need ru.json because items.json may have bad (not localized) names
      h.include?((t = locale.fetch("#{id} ShortName"  ).downcase)) or next(h[t] = id)
      h.include?((t = locale.fetch("#{id} Name"       ).downcase)) or next(h[t] = id)
      h.include?((t = locale.fetch("#{id} Description").downcase)) or next(h[t] = id)
    end.compact
    all.keys.group_by(&:itself).each{ |k, g| fail k.inspect if 1 < g.size }
    all.fetch(smart_match query, all.keys, &:itself).then do |id|
      {
        "614451b71e5874611e2c7ae5" => "5d40407c86f774318526545a",
      }.fetch id, id
    end
  end
  private_class_method :get_item_id

  require "oga"
  def self.parse_response response
    return "не удалось найти предмет с id=%{id}" unless item = response["data"]["items"][0]
    (trader, price) = item["sellFor"].map do |_|
      [_["vendor"]["name"], _["priceRUB"]] unless "Барахолка" == _["vendor"]["name"]
    end.compact.max_by(&:last)
    [
      *("барахолка #{item["lastLowPrice"]}-#{item["lastLowPrice"]}" if item["high24hPrice"]),
      *("#{trader} #{price}" if price),
    ].then do |ways|
      ways.empty? ? "#{item["name"]} не продать" : "куда продать #{item["name"]}: #{ways.join ", "}"
    end
  end
  private_class_method :parse_response

  require "nakischema"

  SCHEMA_PRICE = { hash: {
    "data" => { hash: {
      "items" => { size: 0..1, each: { hash: {
        "name" => /\S/,
        "lastLowPrice" => 0..1000000000,
        "high24hPrice" => [nil, 1..1000000000],
        "width" => 1..6,
        "height" => 1..6,
        "sellFor" => { size: 0..10, each: { hash: {
          "priceRUB" => 1..1000000000,
          "vendor" => { hash: {"name" => /\S/} },
        } } }
      } } }
    } }
  } }
  @prev_price_timestamp = Time.now - 12
  def self.price query
    id = get_item_id query
    sleep [@prev_price_timestamp + 11 - Time.now, 0].max
    @prev_price_timestamp = Time.now
    # https://api.tarkov.dev/graphql
    # https://github.com/the-hideout/tarkov-api/blob/main/schema.js
    # TODO: why 'item' threw an error if it is listed among possible queries?
    parse_response( ::JSON.load( ::NetHTTPUtils.request_data("https://api.tarkov.dev/", :POST, :json, form: {
      "query" => "{ items (ids:\"#{id}\",lang:ru) {
        name
        lastLowPrice
        high24hPrice
        width
        height
        sellFor {
          priceRUB
          vendor { name }
        }
      } }"
    } ) ).tap do |_|
      ::Nakischema.validate _, SCHEMA_PRICE
    end ) % {id: id}
  end

  def self.is_asking_track line
    line = line.downcase
    return if 54 < line.size
    return if [
      /\bч(е|ё|то) (это )?за (\S+ )?тр[еэ]к (был|в 2023)/i,
      /\bпредыдущий\b/i,
      /\.\.\.\s+\S+/,
      /\bпри\b/i,
      /\bбыла\b/i,
      /\bпримерно\b/i,
      /\bреагирует\b/i,
      /\bодин\b/i,
      /\bнорм\b/i,
    ].any? do |r|
      r === line
    end
    [
      /\bч(о|е|ё|то) (это )?за( (\S+ )?)?(тр[еэ]к|музыка|песня)\b/i,
      /\b(дайте|можно) тр[еэ]к\b/i,
      /\bможно название тр[еэ]ка\b/i,
      /\bкак тр[еэ]к называется\b/i,
      /\bкинь\b(.+\b)ссылку на тр[еэ]к\b/i,
      /\bскинь\b(.+\b)тр[еэ]к\b/i,
    ].any? do |r|
      r === line
    end
  end

  require "yaml/store"
  def self.init_repdb prefix
    @repdb = YAML::Store.new "#{prefix}.repdb.yaml"
  end
  def self.rep_chart where
    {}.tap do |h|
      @repdb.transaction(true) do |db|  # TODO: (true)?
      db.roots.each do |root|
        _where, who, what = root
        next if %w{ sha512_ecdsa qomg joyk73 dreame8 }.include? who
        next unless _where == where.downcase
        h[what] ||= 0
        h[what] += db[root][0]
      end
      end
    end
  end
  # DB is case-insensitive
  def self._rep_read where, _what
    h = rep_chart where
    v = h.fetch _what.downcase, 0
    i = 1 + [0, *h.values].uniq.sort.reverse.index(v)
    "#{v} (top-#{i})"
  end
  private_class_method :_rep_read
  def self.rep_read_precise where, who
    "@#{who}'s current rep is #{_rep_read where, who}"
  end
  def self.rep_read where, who
    h = rep_chart where
    who, v = smart_match(who, h, &:first)
    i = 1 + [0, *h.values].uniq.sort.reverse.index(v)
    "@#{who}'s current rep is #{v} (top-#{i})"
  end
  def self._rep_change where, _who, _what
    who, what = _who.downcase, _what.downcase
    is_admin = ("##{who}" == where.downcase)  # TODO: move out to the chat protocol description
    return "@#{_who} " + <<~HEREDOC.split(?\n).sample if who == what
      if only this was that easy
      do you think you are the smartest one?
      try harder
    HEREDOC
    @repdb.transaction do |db|
      db[[where, who, what]].then do |rep, timestamp|
        return "@#{_who} wait another 24h to change @#{_what}'s rep" if timestamp && timestamp + 86400 > Time.now.to_i && !is_admin
        db[[where, who, what]] = [yield(rep||0), Time.now.to_i]
      end
    end
    "@#{_what}'s rep is now #{_rep_read where, _what}"
  end
  private_class_method :_rep_change
  def self.rep_plus where, who, what
    _rep_change(where, who, what){ |_| _ + 1 }
  end
  def self.rep_minus where, who, what
    _rep_change(where, who, what){ |_| _ - 1 }
  end

  require "unicode/blocks"
  def self.chatai query, max_tokens = 150, temperature = 0
    model = nil
      blocks = Unicode::Blocks.blocks_counted query
    [
      # ["zukijourney.xyzbot.net/unf", "zuki.secret", "gpt-4"],
      ["api.naga.ac/v1", "gpt.secret", "gpt-3.5-turbo"],
      # ["api.naga.ac/v1", "gpt.secret", "claude-instant"],   # deprecated?
    ].each do |endpoint, secret, model|
      return JSON.load( begin
        NetHTTPUtils.request_data "https://#{endpoint}/chat/completions", :POST, :json,
          header: {"Authorization" => "Bearer #{File.read secret}"},
        form: {
          "model" => model,
          "messages" => [{
            "role" => "user",
            "content" => query + (
              blocks.fetch("Basic Latin", 0) > blocks.fetch("Cyrillic", 0) ?
                " . limit yourself to 450 chars" :
                " . ограничься 30 словами"
            )
          }],
          "max_tokens" => max_tokens,
          "temperature" => temperature,
        }
      rescue NetHTTPUtils::Error
      fail unless 400 == $!.code || [
        '{"detail":"Forbidden: flagged moderation category: sexual"}',
        '{"error":{"message":"Forbidden: flagged moderation categories: self-harm, self-harm/intent, self-harm/instructions"}}',
        '{"error":{"message":"Forbidden: flagged moderation category: harassment"}}',
        '{"error":{"message":"Oops, no sources were found for this model!"}}',
      ].include?($!.body)
      puts $!
        next
      end ).tap do |json|
        Nakischema.validate p(json), { hash_req: {
        "choices" => [[
          { hash: {
            "finish_reason" => ["stop", "length", nil],
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
    end["choices"][0]["message"]["content"]
    end
    fail "rejected by all providers"
  end

end

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

  def self.clip where, query
  request = lambda do |mtd, **form|
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
  user_id = request["users", "login" => where[/\A#*(.+)/, 1]]["data"][0]["id"]
  f = lambda do |cursor = nil|
    t = request["clips", broadcaster_id: user_id, first: 100, **(cursor ? { after: cursor } : {})]
    t["data"] + t["pagination"]["cursor"].then{ |_| _ ? f[_] : [] }
  end
  smart_match(query, f.call.sort_by{ |_| -_["view_count"] }){ |_| _["title"] }.values_at("title", "url").join " "
  end

  def self.get_item_name query
    locale = JSON.load File.read "Server/project/assets/database/locales/global/ru.json"
    all = JSON.load(File.read "Server/project/assets/database/templates/items.json").each_with_object({}) do |(id, item), h|
      fail id unless id == item["_id"]
      next if "Node" == item["_type"]
      fail unless "Item" == item["_type"]
      next if "557596e64bdc2dc2118b4571" == item.fetch("_parent")   # Pockets
      next if "6050cac987d3f925bf016837" == item.fetch("_parent")   # SortingTable
      next if "566965d44bdc2d814c8b4571" == item.fetch("_parent")   # LootContainer
      next if "62f109593b54472778797866" == item.fetch("_parent")   # RandomLootContainer
      next if "566abbb64bdc2d144c8b457d" == item.fetch("_parent")   # Stash
      h.include?((t = locale.fetch("#{id} ShortName"  ).downcase)) or next(h[t] = locale.fetch "#{id} Name")
      h.include?((t = locale.fetch("#{id} Name"       ).downcase)) or next(h[t] = locale.fetch "#{id} Name")
      h.include?((t = locale.fetch("#{id} Description").downcase)) or next(h[t] = locale.fetch "#{id} Name")
    end.compact
    # p all.size
    # p all.keys.uniq.size
    all.keys.group_by(&:itself).each{ |k, g| fail k.inspect if 1 < g.size }
    all.fetch smart_match query, all.keys, &:itself
  end
  private_class_method :get_item_name

  require "oga"
  def self.parse_response txt
    html = Oga.parse_html txt.force_encoding "utf-8"
    prices = html.xpath("//*[@data-element_type='container' and .//*[@data-widget_type='heading.default' and starts-with(normalize-space(.),'Продать ')]]/following-sibling::*[1]//figcaption").map do |_|
      [
        _.at_xpath("./text()").text,
        case t = _.at_css("*[data-display-name='detailed']").text
        when /\A\s*(\d+(?: \d+)*)\s+₽\z/ ; [$1.scan(/\d+/).join, "₽"]
        when /\A\s*\$(\d+(?: \d+)*)\s*\z/ ; [$1.scan(/\d+/).join, "$"]
        when "—\n", "Забанен\n" ; nil
        else ; fail "error: bad price value: #{t.inspect}"
        end
      ]
    end.select(&:last).to_h
    [
      *("барахолка - #{html.at_xpath("//figcaption[text()='Барахолка']//*[@data-name='entity_field_field_price']").text.gsub(/(\d) (\d)/, '\1\2')}" if prices.delete "Барахолка"),
      *prices.group_by{ |_, (_, currency)| currency }.map{ |c, g| g.max_by{ |t, (price, c)| price.to_i }.then{ |t, (p, c)| "#{t} - #{p} #{c}" } }
    ].then do |ways|
      ways.empty? ? "%s не продать" : "Куда продать %s: #{ways.join ", "}"
    end
  end
  private_class_method :parse_response

  def self.price query
    name = get_item_name query
    parse_response( NetHTTPUtils.request_data( (
      JSON.load( NetHTTPUtils.request_data "https://tarkov.team/_drts/entity/directory__listing/query/items_dir_ltg/", form: {
        _type_: :json,
        no_url: 0,
        num: 15,
        query: name,
        v: "1.3.105-2023-20-0",
      } ).min_by do |_|
        DidYouMean::Levenshtein.distance name, _["title"]
      end or return "can't find #{name.inspect}"
    ).fetch "url" ).tap{ |_| File.write "temp.htm", _ } ) % name.inspect
  end

  def self.is_asking_track line
    line = line.downcase
    return if [
      /\bч(е|ё|то) (это )?за (\S+ )?трек был\b/
    ].any? do |r|
      r === line
    end
    [
      /\bч(о|е|ё|то) (это )?за( (\S+ )?)?(тр[еэ]к|музыка)\b/,
      /\b(дайте|можно) тр[еэ]к\b/,
      /\bможно название тр[еэ]ка\b/,
      /\bкак тр[еэ]к называется\b/,
      /\bкинь\b(.+\b)ссылку на тр[еэ]к\b/,
    ].any? do |r|
      r === line
    end
  end

  require "yaml/store"
  def self.init_repdb prefix
    @repdb = YAML::Store.new "#{prefix}.repdb.yaml"
  end
  def self._rep_read _where, _what
    where, what = _where.downcase, _what.downcase
    h = {}
    @repdb.transaction do |db|  # TODO: (true)?
      db.roots.each do |root|
        _where, _, _what = root
        next unless _where == where
        h[_what] ||= 0
        h[_what] += db[root][0]
      end
    end
    v = h.fetch what, 0
    i = 1 + [0, *h.values].uniq.sort.reverse.index(v)
    "#{v} (top-#{i})"
  end
  private_class_method :_rep_read
  def self.rep_read where, who
    "@#{who}'s current rep is #{_rep_read where, who}"
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

end

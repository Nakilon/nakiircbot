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
  File.write "tokens.secret", NetHTTPUtils.request_data("https://id.twitch.tv/oauth2/token", :POST, form: {
    client_id: File.read("clientid.secret"),
    client_secret: File.read("secret.secret"),
    grant_type: "refresh_token",
    refresh_token: JSON.load(File.read("tokens.secret"))["refresh_token"]
  } )
end

def clip where, query
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

module Common
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
  def self.price query
    name = get_item_name query
    html = Oga.parse_html NetHTTPUtils.request_data( ( JSON.load( NetHTTPUtils.request_data "https://tarkov.team/_drts/entity/directory__listing/query/items_dir_ltg/", form: {
      _type_: :json,
      no_url: 0,
      num: 1,
      query: name,
      v: "1.3.105-2023-20-0",
    } ).first or return "can't find #{name.inspect}" ).fetch("url") ).tap{ |_| File.write "temp.htm", _ }.force_encoding "utf-8"
    "#{
      html.at_css("[data-name='entity_field_field_prodat_torgovcu']").text
    } купит #{name.inspect} за #{
      html.at_css("[data-name='entity_field_field_cena_prodazi_torgovca'] > .drts-entity-field-value").text.gsub(/(\d) (\d)/, '\1\2')
    }" + if html.at_css(".e-con-full [data-name='entity_field_field_price'] > .drts-entity-field-value")
      return "can't parse price for #{name.inspect}" if html.at_css(".minus")
      # html.at_css("[data-name='entity_field_field_slots'] > .drts-entity-field-value").text
      ", цена в барахолке: #{html.at_css("[data-name='entity_field_field_avg7daysprice'] > .drts-entity-field-value").text.gsub(/(\d) (\d)/, '\1\2')}"
    else
      return "can't parse price for #{name.inspect}" unless html.at_css(".minus")
      ""
    end
  end
end

require "functions_framework"
require "google/cloud/pubsub"
topic = Google::Cloud::Pubsub.new.topic "velik", skip_lookup: true

FunctionsFramework.http do |request|
  s = JSON.load request.body.read
  logger << "#{s}\n"

  # -1001681138081 velik_test
  if s.is_a?(Hash) && -1001172940616 == s.dig("message", "chat", "id") && s["message"]["text"]
    topic.publish_async JSON.dump( {
      addr: "#ruby-ru",
      msg: "[tg] #{s["message"]["from"]["username"]}: #{s["message"]["text"]}",
    } ){ |result| logger << "#{result.succeeded?}\n" }
  end

  "OK"
end

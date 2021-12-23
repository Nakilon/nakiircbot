require "functions_framework"
require "google/cloud/pubsub"
topic = Google::Cloud::Pubsub.new.topic "velik", skip_lookup: true

FunctionsFramework.http do |request|
  s = JSON.load request.body.read
  logger << s

  # -1001681138081 velik_test
  if s.is_a?(Hash) && -1001172940616 == s.dig("message", "chat", "id")
    topic.publish_async JSON.dump( {
      addr: "#ruby-ru",
      msg: "[tg] #{s["message"]["from"]["username"]}: #{s["message"]["text"]}",
    } ) do |result|
      logger << result.succeeded?
      logger << result
    end
    topic.async_publisher.stop.wait!
  end

  "OK"
end

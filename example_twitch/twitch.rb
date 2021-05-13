require_relative "../lib/nakiircbot"
require_relative "ping"
NakiIRCBot.start "irc.chat.twitch.tv", "6667", "velik_bot", "nakilon", "freenode Internet Relay Chat Network", "#nakilon",
    password: File.read("password"), masterword: File.read("masterword"),
    processors: %w{ ping.rb }, twitch: true do |str, add_to_queue|
  ping_command_processor str, add_to_queue
end

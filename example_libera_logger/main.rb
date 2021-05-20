require "nakiircbot"
NakiIRCBot.start "irc.libera.chat", "6666", "velik", "nakilon", "Libera.Chat Internet Relay Chat Network", "#esoteric",
    password: File.read("password"), masterword: File.read("masterword") do |*| end

require "minitest/autorun"
require "minitest/around/spec"  # we need Timeout because of blocking #gets

require "socket"
server = TCPServer.new 6666
ENV["VELIK_NICKNAME"] = "velik2"
ENV["VELIK_SERVER"] = "localhost"
# ENV["VELIK_CHANNEL"] = "##nakilon"
Thread.new{ require_relative "main" }
client = server.accept
client.gets
client.gets

describe "fast" do
  around{ |test| Timeout.timeout(0.1){ test.call } }
  it "ping" do
    client.puts ":user!user PRIVMSG #channel :ping"
    fail unless "PRIVMSG #channel :pong\n" == client.gets
  end
end
describe "slow 3" do
  around{ |test| Timeout.timeout(3){ test.call } }
  it "[wiki ...]" do
    client.puts ":user!user PRIVMSG #channel :search with spaces [wiki bitwise cyclic tag], users [wiki user:nakilon], ignore dups [wiki user:nakilon], in text [wiki nakilon], weird chars [wiki created by Stack Exchange users]"
    fail unless "PRIVMSG #channel :https://esolangs.org/wiki/Bitwise%20Cyclic%20Tag https://esolangs.org/wiki/User:Nakilon https://esolangs.org/wiki/Velik https://esolangs.org/wiki/%3F%3F%3F\n" == client.gets
  end
end
describe "slow 1" do
  around{ |test| Timeout.timeout(1){ test.call } }
  it "\\wiki" do
    client.puts ":user!user PRIVMSG #channel :\\wiki asd"
    fail unless "PRIVMSG #channel :ok asd\n" == p(client.gets)
  end
end

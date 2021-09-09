require "socket"
server = TCPServer.new 6666
Thread.new do
  client = server.accept
  client.gets
  client.gets
  begin
    client.puts ":user!user PRIVMSG #channel :ping"
    fail unless "PRIVMSG #channel :pong\n" == client.gets
    client.puts ":user!user PRIVMSG #channel :search with spaces [wiki bitwise cyclic tag], users [wiki user:nakilon], ignore dups [wiki user:nakilon], in text [wiki nakilon], weird chars [wiki created by Stack Exchange users]"
    fail unless "PRIVMSG #channel :https://esolangs.org/wiki/Bitwise%20Cyclic%20Tag https://esolangs.org/wiki/User:Nakilon https://esolangs.org/wiki/Velik https://esolangs.org/wiki/%3F%3F%3F\n" == client.gets
  rescue
    puts "TESTS FAILED"
    exit 1
  else
    puts "TESTS PASSED"
    exit
  end
end

ENV["VELIK_NICKNAME"] = "velik2"
ENV["VELIK_SERVER"] = "localhost"
ENV["VELIK_CHANNEL"] = "##nakilon"
require_relative "main"

require "socket"
server = TCPServer.new 6666
Thread.new do
  client = server.accept
  client.gets
  client.gets
  begin
    client.puts ":user!user PRIVMSG #channel :ping"
    fail unless "PRIVMSG #channel :pong\n" == client.gets
    client.puts ":user!user PRIVMSG #channel :there is [wiki rasel] but no [wiki huyasel], [wiki user:nakilon] made this test"
    fail unless "PRIVMSG #channel :https://esolangs.org/wiki/Rasel https://esolangs.org/wiki/Users:nakilon\n" == client.gets
  rescue
    exit 1
  else
    exit
  end
end
require_relative "main"

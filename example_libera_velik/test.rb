require "minitest/autorun"
require "minitest/around/spec"  # we need Timeout because of blocking #gets

require "socket"
server = TCPServer.new 6666
ENV["VELIK_NICKNAME"] = "velik2"
ENV["VELIK_SERVER"] = "localhost"
# ENV["VELIK_CHANNEL"] = "##nakilon"
Thread.new{ require_relative "main" }
require "timeout"
client = Timeout.timeout(2){ server.accept.tap(&:gets).tap(&:gets) }

# TODO: actually use proper Minitest assertion methods
# TODO: do something about replies that get mixed once there is a single fail,
#       otherwise there is no point in having tests separated

describe "fast" do
  around{ |test| Timeout.timeout(0.1){ test.call } }
  it "ping" do
    client.puts ":user!user PRIVMSG #channel :ping"
    fail unless "PRIVMSG #channel :pong\n" == client.gets
  end
end
describe "[wiki ...]" do
  around{ |test| Timeout.timeout(4){ test.call } }
  it "[wiki ...]" do
    client.puts ":user!user PRIVMSG #channel :search with spaces [wiki bitwise cyclic tag], users [wiki user:nakilon], ignore dups [wiki user:nakilon], in text [wiki nakilon], weird chars [wiki created by Stack Exchange users]"
    fail unless "PRIVMSG #channel :https://esolangs.org/wiki/Bitwise%20Cyclic%20Tag https://esolangs.org/wiki/User:Nakilon https://esolangs.org/wiki/Velik https://esolangs.org/wiki/%3F%3F%3F\n" == client.gets
  end
end
describe "\\wiki" do
  around{ |test| Timeout.timeout(3){ test.call } }
  it "\\wiki Linux" do
    # templates: About, Short
    client.puts ":user!user PRIVMSG #channel :\\wiki Linux"
    assert /\APRIVMSG #channel :(?<reply>.+)\n\z/ =~ client.gets
    assert_equal " (alt: 'Linux kernel') Family of Unix-like operating systems", reply
  end
  it "\\wiki Linux (Linux kernel)" do
    # templates: Short
    client.puts ":user!user PRIVMSG #channel :\\wiki Linux kernel"
    assert /\APRIVMSG #channel :(?<reply>.+)\n\z/ =~ client.gets
    assert_equal " Free and open-source Unix-like operating system kernel", reply
  end
  it "\\wiki VPCLMULQDQ" do   # search results page (found by section name but it does not matter)
    # templates: none
    client.puts ":user!user PRIVMSG #channel :\\wiki VPCLMULQDQ"
    assert /\APRIVMSG #channel :(?<reply>.+)\n\z/ =~ client.gets
    assert reply.start_with? " AVX-512 are 512-bit extensions to the 256-bit Advanced Vector Extensions SIMD instructions "
  end
end

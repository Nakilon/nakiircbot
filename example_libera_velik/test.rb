require "minitest/autorun"
require "minitest/around/spec"  # we need Timeout because of blocking #gets

require "socket"
server = TCPServer.new 6666
ENV["VELIK_NICKNAME"] = "velik2"
ENV["VELIK_SERVER"] = "localhost"
# ENV["VELIK_CHANNEL"] = "##nakilon"
Thread.new{ require_relative "main" }
require "timeout"
client = Timeout.timeout(6){ server.accept.tap(&:gets).tap(&:gets) }

# TODO: do something about replies that get mixed once there is a single fail,
#       otherwise there is no point in having tests separated

describe "fast" do
  around{ |test| Timeout.timeout(0.1){ test.call } }
  it "ping" do
    client.puts ":user!user PRIVMSG #channel :ping"
    assert_equal "PRIVMSG #channel :pong\n", client.gets
  end
  it "\\help" do
    client.puts ":user!user PRIVMSG #channel :\\help"
    assert_equal "PRIVMSG #channel :available commands: [\"wiki\", \"wp\", \"rasel\", \"morse\", \"demorse\"]; usage help: \\help <cmd>\n", client.gets
  end
  it "\\help wp" do
    client.puts ":user!user PRIVMSG #channel :\\help wp"
    assert_equal "PRIVMSG #channel :\\wp <wikipedia article or search query>\n", client.gets
  end
end
describe "[[...]]" do
  around{ |test| Timeout.timeout(3){ test.call } }
  it "' ', ':', dup, unexisting" do   # TODO: split
    client.puts ":user!user PRIVMSG #channel :search with spaces [[bitwise cyclic tag]], users [[user:nakilon]], ignore dups [[user:nakilon]], in text [[nakilon]], weird chars [[created by Stack Exchange users]]"
    assert /\APRIVMSG #channel :(?<reply>.+)\n\z/ =~ client.gets
    assert_equal "https://esolangs.org/wiki/Bitwise%20Cyclic%20Tag https://esolangs.org/wiki/User:Nakilon https://esolangs.org/wiki/Velik https://esolangs.org/wiki/%3F%3F%3F", reply
  end
  # it "brainfuck" do
  #   client.puts ":user!user PRIVMSG #channel :[[brainfuck]]"
  #   assert /\APRIVMSG #channel :(?<reply>.+)\n\z/ =~ client.gets
  #   assert_equal "https://esolangs.org/wiki/Brainfuck", reply
  # end
end
describe "\\wp" do
  around{ |test| Timeout.timeout(5){ test.call } }
  it "москва" do   # this article About template does not provide a single alternative link
    # templates: About, Short
    client.puts ":user!user PRIVMSG #channel :\\wp москва"
    assert /\APRIVMSG #channel :(?<reply>.+)\n\z/ =~ client.gets
    assert_equal " Moscow -- capital and most populous city of Russia https://en.wikipedia.org/wiki/Moscow", reply
  end
  it "linux" do
    # templates: About, Short
    client.puts ":user!user PRIVMSG #channel :\\wp linux"
    assert /\APRIVMSG #channel :(?<reply>.+)\n\z/ =~ client.gets
    assert_equal " (see also: Linux kernel) Linux -- family of Unix-like operating systems that use the Linux kernel and are open source https://en.wikipedia.org/wiki/Linux", reply
  end
  it "linux kernel" do
    # templates: Short
    client.puts ":user!user PRIVMSG #channel :\\wp linux kernel"
    assert /\APRIVMSG #channel :(?<reply>.+)\n\z/ =~ client.gets
    assert_equal " Linux kernel -- Unix-like operating system kernel, basis for all Linux operating systems / Linux distributions https://en.wikipedia.org/wiki/Linux_kernel", reply
  end
  it "vpclmulqdq" do   # search results page (found by section name but it does not matter)
    # templates: none
    client.puts ":user!user PRIVMSG #channel :\\wp vpclmulqdq"
    assert /\APRIVMSG #channel :(?<reply>.+)\n\z/ =~ client.gets
    assert_equal " AVX-512 -- Instruction set extension developed by Intel https://en.wikipedia.org/wiki/AVX-512", reply
  end
end
describe "\\wiki" do
  around{ |test| Timeout.timeout(3){ test.call } }
  it "user:nakilon" do
    client.puts ":user!user PRIVMSG #channel :\\wiki user:nakilon"
    assert /\APRIVMSG #channel :(?<reply>.+)\n\z/ =~ client.gets
    assert_match /\A Hello, I made the RASEL language\. Also the IRC bot velik .+\. https:\/\/esolangs\.org\/wiki\/User:Nakilon\z/, reply
  end
end

require "webmock/minitest"
require_relative "webmock_patch"
describe "\\wa" do
  around do |test|
    WebMock.enable!
    Timeout.timeout(5){ test.call }
    WebMock.disable!
  end
  before{ WebMock.reset! }
  def cmd client, cmd
    client.puts ":user!user PRIVMSG #channel :\\wa #{cmd}"
    assert /\APRIVMSG #channel :(.+)\n\z/ =~ client.gets.force_encoding("utf-8")
    $1
  end
  def stub query, file
    stub_request(:get, "http://api.wolframalpha.com/v2/query").with(query: hash_including({})).to_return body: File.read("wa/#{file}.xml")
  end
  it "π" do   # entered by user as greek
    stub "π", "pig"
    assert_equal \
      " Decimal approximation: \x023.1415926535897932384626433832795028841971693993751058209749445923...\x0f | Property: \x02π is a transcendental number\x0f | Continued fraction: \x02[3; 7, 15, 1, 292, 1, 1, 1, 2, 1, 3, 1, 14, 2, 1, 1, 2, 2, 2, 2, 1, 84, 2, 1, 1, 15, 3, 13, ...]\x0f",
      cmd(client, "π")
  end
  it "pi" do  # interpreted by server as greek
    stub "pi", "pil"
    assert_equal \
      " Decimal approximation: \x023.1415926535897932384626433832795028841971693993751058209749445923...\x0f | Property: \x02π is a transcendental number\x0f | Continued fraction: \x02[3; 7, 15, 1, 292, 1, 1, 1, 2, 1, 3, 1, 14, 2, 1, 1, 2, 2, 2, 2, 1, 84, 2, 1, 1, 15, 3, 13, ...]\x0f",
      cmd(client, "pi")
  end
  it "125 + 375" do
    stub "125 + 375", "125375"
    assert_equal " Result: \x02500\x0f | Number name: \x02five hundred\x0f", cmd(client, "125 + 375")
  end
end

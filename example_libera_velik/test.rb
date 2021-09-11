require "minitest/autorun"
require "minitest/around/spec"  # we need Timeout because of blocking #gets

require "socket"
server = TCPServer.new 6666
ENV["VELIK_NICKNAME"] = "velik2"
ENV["VELIK_SERVER"] = "localhost"
# ENV["VELIK_CHANNEL"] = "##nakilon"
Thread.new{ require_relative "main" }
require "timeout"
client = server.accept.tap(&:gets).tap(&:gets)

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
  around{ |test| Timeout.timeout(8){ test.call } }
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
    Timeout.timeout(7){ test.call }
    WebMock.disable!
  end
  before do
    WebMock.reset!
    @client = client
  end
  def cmd cmd
    @client.puts ":user!user PRIVMSG #channel :\\wa #{cmd}"
    assert /\APRIVMSG #channel :(.+)\n\z/ =~ @client.gets.force_encoding("utf-8")
    $1
  end
  def stub_and_assert query, file, expectation = nil
    # https://github.com/bblimke/webmock/issues/693#issuecomment-285485320
    stub_request(:get, "http://api.wolframalpha.com/v2/query").with(query: hash_including({})).to_return body: File.read("wa/#{file}.xml") if file  # pass nil file to prepare webmock
    cmd(query).tap do |reply|
      refute_match "unsupported scanner", reply
      assert_equal expectation, reply if expectation
    end
  end
  it "pig" do   # entered by user as greek
    stub_and_assert "π", "pig"
  end
  it "pil" do   # interpreted by server as greek
    stub_and_assert "pi", "pil"
  end
  describe "Mathematics" do
    it "arithmetic" do  # no assumption
      stub_and_assert "125 + 375", "arithmetic"
    end
    it "fractions" do   # multiple primary
      stub_and_assert "1/4 * (4 - 1/2)", "fractions", " Exact result: \x027/8\x0f | Decimal form: \x020.875\x0f | Continued fraction: \x02[0; 1, 7]\x0f | Egyptian fraction expansion: \x021/2 + 1/3 + 1/24\x0f"
    end
    it "equation" do    # multiple subpods
      stub_and_assert "x^3 - 4x^2 + 6x - 24 = 0", "equation", " Real solution: \x02x = 4\x0f | Complex solutions: \x02x = -i sqrt(6), x = i sqrt(6)\x0f | Alternate forms: \x02(x - 4) (x^2 + 6) = 0, (x - 4/3)^3 + 2/3 (x - 4/3) - 560/27 = 0\x0f"
    end
    it "factor" do
      stub_and_assert "factor 2x^5 - 19x^4 + 58x^3 - 67x^2 + 56x - 48", "factor"
    end
    it "simplify" do
      stub_and_assert "1/(1+sqrt(2))", "simplify"
    end
    it "integral" do    # [LF]
      stub_and_assert "integrate sin x dx from x=0 to pi", "integral", " Visual representation of the integral: \x02\x0f | Indefinite integral: \x02integral sin(x) dx = -cos(x) + constant\x0f | Riemann sums: \x02left sum | (π cot(π/(2 n)))/n = 2 - π^2/(6 n^2) + O((1/n)^4) (assuming subintervals of equal length)\x0f"
    end
    it "derivative" do
      stub_and_assert "derivative of x^4 sin x", "derivative"
    end
  end
end

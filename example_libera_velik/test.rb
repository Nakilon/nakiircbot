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
      refute_match "[LF]", reply
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
    describe "main" do
      describe "Elementary Math" do
        it "arithmetic" do
          stub_and_assert "125 + 375", "arithmetic"
        end
        it "fractions" do   # multiple primary
          stub_and_assert "1/4 * (4 - 1/2)", "fractions", " Exact result: \x027/8\x0f | Decimal form: \x020.875\x0f | Continued fraction: \x02[0; 1, 7]\x0f | Egyptian fraction expansion: \x021/2 + 1/3 + 1/24\x0f"
        end
      end
      describe "Algebra" do
        it "equation" do  # Reduce?
          stub_and_assert "x^3 - 4x^2 + 6x - 24 = 0", "equation", " Real solution: \x02x = 4\x0f | Complex solutions: \x02x = -i sqrt(6), x = i sqrt(6)\x0f | Alternate forms: \x02(x - 4) (x^2 + 6) = 0, (x - 4/3)^3 + 2/3 (x - 4/3) - 560/27 = 0\x0f"
        end
        it "factor" do
          stub_and_assert "factor 2x^5 - 19x^4 + 58x^3 - 67x^2 + 56x - 48", "factor"
        end
        it "simplify" do
          stub_and_assert "1/(1+sqrt(2))", "simplify"
        end
      end
      describe "Calculus & Analysis" do
        it "integral" do    # [LF]
          stub_and_assert "integrate sin x dx from x=0 to pi", "integral", " Indefinite integral: \x02integral sin(x) dx = -cos(x) + constant\x0f | Riemann sums: \x02left sum | (π cot(π/(2 n)))/n = 2 - π^2/(6 n^2) + O((1/n)^4) (assuming subintervals of equal length)\x0f"
        end
        it "derivative" do  # subpods with titles
          stub_and_assert "derivative of x^4 sin x", "derivative", " Indefinite integral: \x02integral x^3 (x cos(x) + 4 sin(x)) dx = x^4 sin(x) + constant\x0f | Expanded form: \x02x^4 cos(x) + 4 x^3 sin(x)\x0f | Alternate form: \x021/2 e^(-i x) x^4 + 1/2 e^(i x) x^4 + 2 i e^(-i x) x^3 - 2 i e^(i x) x^3\x0f | Series expansion at x = 0: \x025 x^4 - (7 x^6)/6 + (3 x^8)/40 - (11 x^10)/5040 + O(x^11) (Taylor series)\x0f | Numerical roots: \x02x ≈ ± 8.30292918259702..., x ≈ ± 5.35403184117202..., x ≈ ± 2.57043156033596..., x = 0, x ≈ 11...."
        end
        it "differential" do  # ODE
          stub_and_assert "y'' + y = 0", "differential", " Differential equation solution: \x02y(x) = c_2 sin(x) + c_1 cos(x)\x0f | Alternate form: \x02y''(x) = -y(x)\x0f | Possible Lagrangian: \x02ℒ(y', y) = 1/2 ((y')^2 - y^2)\x0f | ODE classification: \x02second-order linear ordinary differential equation\x0f | ODE names: \x02Autonomous equation: y''(x) = -y(x), Van der Pol's equation: y''(x) + y(x) = 0\x0f"
        end
      end
      describe "Geometry" do end
      describe "Plotting & Graphics" do end
      describe "Differential Equations" do end
      describe "Statistics" do end
      describe "Mathematical Functions" do end
    end
    describe "Numbers" do end
    describe "Trigonometry" do end
    describe "Linear Algebra" do end
    describe "Discrete Mathematics" do end
    describe "Number Theory" do end
    describe "Complex Analysis" do end
    describe "Applied Mathematics" do end
    describe "Logic & Set Theory" do end
    describe "Continued Fractions" do end
    describe "Mathematical Definitions" do end
    describe "Famous Math Problems" do end
    describe "Common Core Math" do end
    describe "Probability" do end
  end
  describe "Science & Technology" do
    describe "main" do
      describe "Physics" do end
      describe "Chemistry" do
        # it "element" do end
        it "balance" do   # no primary
          stub_and_assert "Al + O2 -> Al2O3", "balance", " Balanced equation: \x024 Al + 3 O_2 ⟶ 2 Al_2O_3\x0f | Word equation: \x02aluminum + oxygen ⟶ aluminum oxide\x0f | Equilibrium constant: \x02K_c = [Al2O3]^2/([Al]^4 [O2]^3)\x0f | Rate of reaction: \x02rate = -1/4 (Δ[Al])/(Δt) = -1/3 (Δ[O2])/(Δt) = 1/2 (Δ[Al2O3])/(Δt) (assuming constant volume and no accumulation of intermediates or side products)\x0f | Reaction thermodynamics: \x02Enthalpy: ΔH_rxn^0 | -3352 kJ/mol - 0 kJ/mol = -3352 kJ/mol (exothermic), Entropy: ΔS..."
        end
      end
      describe "Units & Measures" do end
      describe "Engineering" do end
      describe "Computational Sciences" do end
      describe "Earth Sciences" do end
      describe "Transportation" do end
      describe "Materials" do end
    end
  end
  describe "Society & Culture" do
    describe "main" do
      describe "People" do end
      describe "Arts & Media" do end
      describe "History" do end
      describe "Words & Linguistics" do end
      describe "Money & Finance" do end
      describe "Dates & Times" do end
      describe "Food & Nutrition" do end
      describe "Demographics & Social Statistics" do end
    end
  end
  describe "Everyday Life" do
    describe "main" do
      describe "Personal Health" do end
      describe "Personal Finance" do end
      describe "Surprises" do end
      describe "Entertainment" do end
      describe "Household Science" do end
      describe "Household Math" do end
      describe "Hobbies" do end
      describe "Today's World" do end
    end
  end
end

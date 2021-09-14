require "minitest/autorun"
require "minitest/around/spec"  # we need Timeout because of blocking #gets

require "socket"
server = TCPServer.new 6666
ENV["VELIK_NICKNAME"] = "velik2"
ENV["VELIK_SERVER"] = "localhost"
# ENV["VELIK_CHANNEL"] = "##nakilon"
Thread.new{ require_relative "main" }.abort_on_exception = true
client = server.accept.tap(&:gets).tap(&:gets)

require "timeout"

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
    assert_equal "PRIVMSG #channel :available commands: [\"wiki\", \"wp\", \"wa\", \"rasel\", \"morse\", \"demorse\"]; usage help: \\help <cmd>\n", client.gets
  end
  it "\\help wp" do
    client.puts ":user!user PRIVMSG #channel :\\help wp"
    assert_equal "PRIVMSG #channel :\\wp <Wikipedia article or search query>\n", client.gets
  end
end
describe "[[...]]" do
  around{ |test| Timeout.timeout(5){ test.call } }
  it "spaces" do
    client.puts ":user!user PRIVMSG #channel :[[bitwise cyclic tag]]"
    assert /\APRIVMSG #channel :(?<reply>.+)\n\z/ =~ client.gets
    assert_equal "https://esolangs.org/wiki/Bitwise_Cyclic_Tag", reply
  end
  it "???" do
    client.puts ":user!user PRIVMSG #channel :[[???]]"
    assert /\APRIVMSG #channel :(?<reply>.+)\n\z/ =~ client.gets
    assert_equal "https://esolangs.org/wiki/%3F%3F%3F", reply
  end
  it "':', dup, text search" do
    client.puts ":user!user PRIVMSG #channel :[[user:nakilon]] [[user:nakilon]] [[nakilon]]"
    assert /\APRIVMSG #channel :(?<reply>.+)\n\z/ =~ client.gets
    assert_equal "https://esolangs.org/wiki/User:Nakilon https://esolangs.org/wiki/Velik", reply
  end
  it "also text search" do
    client.puts ":user!user PRIVMSG #channel :[[created by Stack Exchange users]]"
    assert /\APRIVMSG #channel :(?<reply>.+)\n\z/ =~ client.gets
    assert_equal "https://esolangs.org/wiki/%3F%3F%3F", reply
  end
  it "brainfuck" do
    client.puts ":user!user PRIVMSG #channel :[[brainfuck]]"
    assert /\APRIVMSG #channel :(?<reply>.+)\n\z/ =~ client.gets
    assert_equal "https://esolangs.org/wiki/Brainfuck", reply
  end
end
describe "\\wp" do
  around{ |test| Timeout.timeout(10){ test.call } }
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

  it "'pig'" do   # entered by user as greek
    stub_and_assert "π", "pig"
  end
  it "'pil'" do   # interpreted by server as greek
    stub_and_assert "pi", "pil"
  end
  it "'equation'" do  # "not clear what you mean"
    stub_and_assert "equation", "equation", "not clear what you mean"
  end
  it "seconds since" do   # many (4) subpods
    stub_and_assert "seconds since 1 Jan 1970", "since"
  end
  it "arithmetic" do  # [LF]
    stub_and_assert "2+2", "arithmetic", " Result: 4 | Number name: four"
  end
  it "'mass of earth'" do   # microsources, datasources
    stub_and_assert "mass of earth", "earth"
  end
  it "'mass of sun'" do
    stub_and_assert "mass of sun", "sun"
  end
  it "'future'" do  # all results are of Grid expressiontype
    stub_and_assert "future", "future", "results are not printable"
  end
  it "immigrants" do  # expressiontype TimeSeriesPlot
    stub_and_assert "how many immigrants in moscow", "immigrants"
  end
  it "'kolmogorov'" do  # expressiontype TimelinePlot
    stub_and_assert "kolmogorov", "kolmogorov"
  end

  # https://www.wolframalpha.com/examples/
  describe "by topic" do
    def stub_and_assert_by_topic query, file, expectation = nil
      stub_and_assert query, "by_topic/#{file}", expectation
    end
    describe "Mathematics" do
      describe "main" do
        describe "Elementary Math" do
          it "arithmetic" do
            stub_and_assert_by_topic "125 + 375", "arithmetic"
          end
          it "fractions" do   # multiple primary
            stub_and_assert_by_topic "1/4 * (4 - 1/2)", "fractions", " Exact result: 7/8 | Decimal form: 0.875 | Continued fraction: [0; 1, 7] | Egyptian fraction expansion: 1/2 + 1/3 + 1/24"
          end
        end
        describe "Algebra" do
          it "equation" do  # Reduce?
            stub_and_assert_by_topic "x^3 - 4x^2 + 6x - 24 = 0", "equation", " Real solution: x = 4 | Complex solutions: x = -i sqrt(6), x = i sqrt(6) | Alternate forms: (x - 4) (x^2 + 6) = 0, (x - 4/3)^3 + 2/3 (x - 4/3) - 560/27 = 0"
          end
          it "factor" do
            stub_and_assert_by_topic "factor 2x^5 - 19x^4 + 58x^3 - 67x^2 + 56x - 48", "factor"
          end
          it "simplify" do
            stub_and_assert_by_topic "1/(1+sqrt(2))", "simplify"
          end
        end
        describe "Calculus & Analysis" do
          it "integral" do    # [LF]
            stub_and_assert_by_topic "integrate sin x dx from x=0 to pi", "integral", " Indefinite integral: integral sin(x) dx = -cos(x) + constant"
          end
          it "derivative" do  # subpods with titles
            stub_and_assert_by_topic "derivative of x^4 sin x", "derivative", " Indefinite integral: integral x^3 (x cos(x) + 4 sin(x)) dx = x^4 sin(x) + constant | Expanded form: x^4 cos(x) + 4 x^3 sin(x) | Alternate form: 1/2 e^(-i x) x^4 + 1/2 e^(i x) x^4 + 2 i e^(-i x) x^3 - 2 i e^(i x) x^3 | Series expansion at x = 0: 5 x^4 - (7 x^6)/6 + (3 x^8)/40 - (11 x^10)/5040 + O(x^11) (Taylor series) | Numerical roots: x ≈ ± 8.30292918259702..., x ≈ ± 5.35403184117202..., x ≈ ± 2.57043156033596..., x = 0, x ≈ 11.334825583..."
          end
          it "differential" do  # ODE
            stub_and_assert_by_topic "y'' + y = 0", "differential", " Differential equation solution: y(x) = c_2 sin(x) + c_1 cos(x) | Alternate form: y''(x) = -y(x) | Possible Lagrangian: ℒ(y', y) = 1/2 ((y')^2 - y^2) | ODE classification: second-order linear ordinary differential equation | ODE names: Autonomous equation: y''(x) = -y(x), Van der Pol's equation: y''(x) + y(x) = 0"
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
            stub_and_assert_by_topic "Al + O2 -> Al2O3", "balance", " Balanced equation: 4 Al + 3 O_2 ⟶ 2 Al_2O_3 | Word equation: aluminum + oxygen ⟶ aluminum oxide | Equilibrium constant: K_c = [Al2O3]^2/([Al]^4 [O2]^3) | Rate of reaction: rate = -1/4 (Δ[Al])/(Δt) = -1/3 (Δ[O2])/(Δt) = 1/2 (Δ[Al2O3])/(Δt) (assuming constant volume and no accumulation of intermediates or side products)"
          end
        end
        describe "Units & Measures" do end
        describe "Engineering" do end
        describe "Computational Sciences" do end
        describe "Earth Sciences" do end
        describe "Transportation" do end
        describe "Materials" do end
      end
      # ...
    end
    describe "Society & Culture" do
      describe "main" do
        describe "People" do end
        describe "Arts & Media" do end
        describe "History" do end
        describe "Words & Linguistics" do end
        describe "Money & Finance" do end
        describe "Dates & Times" do
          it "subtract" do
            stub_and_assert_by_topic "17 hours from now", "subtract"
          end
          # it "about" do end
        end
        describe "Food & Nutrition" do end
        describe "Demographics & Social Statistics" do end
      end
      # ...
    end
    describe "Everyday Life" do
      describe "main" do
        describe "Personal Health" do end
        describe "Personal Finance" do end
        describe "Surprises" do
          it "chicken" do
            stub_and_assert_by_topic "why did the chicken cross the mobius strip", "chicken"
          end
          # it "warp" do end
        end
        describe "Entertainment" do
          # it "acts" do end
          it "leonardo" do  # trailing '?' gets removed
            stub_and_assert_by_topic "what was the age of Leonardo when the Mona Lisa was painted?", "leonardo"
          end
        end
        describe "Household Science" do end
        describe "Household Math" do end
        describe "Hobbies" do end
        describe "Today's World" do end
      end
      # ...
    end
  end
end

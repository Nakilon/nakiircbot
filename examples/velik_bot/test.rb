require "maxitest/autorun"

require_relative "flace"
Flace "nakischema"
Flace "unicode/blocks"

require_relative "common"
Common.init_repdb "test"

describe "unit1" do

  it "smart_match" do
clips = <<~HEREDOC.split("\n")
  #zaebis четко
  #живиживиживи
  (
  ))))
  +хорошей реги
  - еще один грибник
  -1
  -1 грибник!
  -2
  1
  1 рейд
  1111
  2
  2 минус
  222
  3 босса
  300 IQ play
  333
  47 уровней страданий.
  ???
  akiiz tiaes and a dream
  Apatiya 4x4
  awww hell
  clown
  DROPS ON ✅ Lets Go, E💲cape From ETO TI ?🐀
  FBI open door
  FBI! Open up!
  Follow
  Go back to lobby rat)
  hahahahahahahha
  lya kakaya
  otkisla kiska
  pyk pyk srenlk
  SIDIM PERDIM
  UWU
  Uwu twix
  ZASADA
  А как убить?
  А кто это там под камушком сидит!)
  А ты кто?
  А умереть?
  а умереть?!
  А я тут)
  Актер без оскара
  Алло это Жоска?
  Алло, Буянов?
  Алло, Никита?)
  аххаха
  бегу бегу!!!
  Бой до последнего!
  Большая бутылка
  Боты совсем крейзи!
  Бурные рукоплескания
  Бухлострим ЮХУУУ
  Бэтман
  В лоби)
  в норку
  Валерос МАШИНА 2
  Видеооператор
  Виталик -  мужское русское личное имя древнеримского происхождения.
  Внезапность - сестра таланта)
  Вовчек На турнирчике)))
  Волшебники вне Хогварста
  Вооооон он
  Вопросики
  Восседатель кустарный
  вот здесь меня и убили
  Вот настояший Штурмовик!
  все Враки
  Все дороги ведут в Тарков. 48 уровней страданий.
  Всей своей добротой прошлась по ЧВК!
  встреча с легендой
  встреча с легендой 2
  встреча с легендой 3
  вываливаемся с окон
  Гуд грена однако!
  Да блять)))
  да бляяяяяяяять анкал)))
  Да все нормально! Это Тарков)))
  дали ключ но не дали оружие
  Данила и Ко. Онлайн ,без регистрации...
  Двоих парней обидела)
  Дима тащи патроны
  до первой крови давай
  Доброй ночи, вы верите в христа спасителя?
  донт шут
  Допрыгался))
  Дроп випон!!!!
  ду ю бум-бум
  Дыра в шапке
  Есть 1
  Еще один
  Ещё один не понимающий как так то))
  Живем)
  завтыкал
  задымил
  Зарубили
  Затворная задержка как у м16
  Затупили гунны
  Заявка на por1hub
  значит встречаются два зажиматора...
  и прыгает хахах
  ить, ить! итсь!
  ихих
  Кайфовый турик
  как отписаться
  Как то так
  Какая жалость ребяяяята
  какая же я глупенькая)
  каппа
  Каппа? Сюда
  Кинули на баллы!
  клин, дикий + лут
  ключи потерял
  Коби
  Когда давно не видел ледыксы...
  Когда ЧВК хочет жить больше чем стример)
  Колдунство!
  Конкурс на лучшего актера
  Контент достойный стрима)
  Кошечка перепила Валерьянки!
  Красиво умереть тоже надо уметь)
  краснеющий каллиматор
  Крыси у рубильника!
  кто быстрее залутает 110)
  Кто купил?!
  лежит смотрит
  Лера 18+
  Лера и Два Актера!
  Лера играет в салочки!
  Лера мстит!
  Лера против двух фулочек, которые ее бояться)
  Лера против советского война!
  Лера типа пушит дверь!
  Лерон в топ позиции!
  Лерон всех убивон)
  Лех ты ?
  Лушчая игра это Тарков!
  маза дал
  маршрутка
  мастер крадун))))
  Маугли
  машина
  МАШИНА ЛЕРА
  Минус два, так минус два!
  Минус ценной двух хороших парней!
  Минус!
  Мир,труд,май,Тарков.
  Мки!
  МММ ДЕЛИШЕС <3
  мне п
  Мне так бывшая говорила
  Молекула
  Мстя за Валеру!
  Мы просто мимо пройдем
  МЫШКА СРАБОТАЛА НА СЛАВУ
  Мяу твикса)
  НАНИ!?
  Напали на сашульку
  наэлектризована жопу стулом
  не верит =)
  не убивают
  Нефиг кушать обезбол при Лере)
  Ниндзя
  Ништяк пацаны , завтра на работу)))
  Ништяк пацаны, завтра выходные)))
  Ну ты дурак или че?
  Ну что? Аванпост,пацаны. 44 уровня страданий)
  О херасе, пацан готов.
  обещание сводить на лабу от Etenaris
  обиделась лерка(
  Одним зажимом -2
  окно 3 этаж, справа
  Он знает когда...
  он прыгнул?
  они в окнах
  Оп Смотри че пакажу)
  оп Сюрприз
  опа
  Операция кусты
  Остальные два
  Откровение
  откуда он кидает гранаты? )
  Охота на белку
  Пажжаааалуйста UwU
  Парень устал
  План Эльдара
  Подстава
  Привет)
  приветик))
  Пробный стрим перед вайпом, я вернулся)))
  Продолжение убивание детей!
  Просто смешно сказала))
  пруф
  пруфы что развяка что? ТОП
  прыгну со скалы
  Прыжок Веры Брежневой
  Прыжок ЛЕРЫ
  Прыжок смерти
  Радикулит нам не страшен! (прицел забагало)
  Разницы никакой
  Расслабление Карася
  регистрация
  С ДР.
  СБЭУ ПОБЕДИЛО!!!
  Свой или чужой?
  свой среди чужих аха
  скажите пожалуйста
  Скайлайн джтр
  Скилл не пропиешь
  Скример
  снайпер блять)))
  снайперская перестрелка
  Спортсмен однако!
  Страх и ненависть в Таркове
  Страшно же так выпригивать
  Судороги
  Счастливая!
  та мне пизда..... а нет ! не пизда!
  Тарков ну совсем не страшный!
  тарковские крипы
  Твикс девушка лежебоки verified
  тоже база
  Трипер
  Турнирчик.)
  Тутуту ту ту тутутут
  Ты по металлу шлепаешь?
  У Леры грены умные)
  У нас замена
  Убегает с красным стволом
  Убивца!
  Убила флешкой
  Убрали лут с карт. Вайп близко.
  УВУ ИВАНА (СИЛЬНО)
  Удивление
  Улач
  улица
  умер молодым
  устал присел прилёг
  Уууу везение))))
  Фиркос не блять)))
  Хоба
  Хорошая
  Хорошая попытка Джони)
  Хорошо приняла!
  Хотел уехать, не получилось
  Чаво
  чекай
  чит
  Читак?
  Читеров в игре нету)
  что
  Что с греной?
  что тут происходит
  Что Что Что????!!!
  Что-то узнать хотел
  Чудо!
  Чупа без Мки теперь
  шо
  што?
  Ыыыы, поржал
  Эй парень иди сюда)))
  это не размен)))
  это тильт
  Это ты? Тормози!
  Это я
  Эээто был ты....
  Я вообще-то..
  Я кого то убила?!
  я не флудил
  я нейросеть
  Я с Сахалина
  я твой мансуль
  Ёлочки
  №"!"@#!
HEREDOC

fail unless "Алло, Буянов?" == smart_match("буянов", clips, &:itself)
fail unless "это тильт" == smart_match("тильт", clips, &:itself)
fail unless "МАШИНА ЛЕРА" == smart_match("лера машина", clips, &:itself)
  end

  it "#get_item_name #parse_response" do
fail unless "Статуэтка кота" == p(Common.method(:get_item_name).("кот"))
fail unless "Бутылка пива \"Певко светлое\"" == p(Common.method(:get_item_name).("пивко"))
fail unless "Набор медикаментов" == p(Common.method(:get_item_name).("мед."))
fail unless "12/70 флешетта" == p(Common.method(:get_item_name).("флешетты"))  # TwixFix
fail unless "Куда продать %s: барахолка - 29900 ₽, Терапевт - 8343 ₽" == p(Common.method(:parse_response).(File.read "pevko.htm"))  # +барахолка -$
fail unless "Куда продать %s: Барахольщик - 232190 ₽, Миротворец - 1416 $" == p(Common.method(:parse_response).(File.read "slick.htm"))  # -барахолка +$spaces
    assert_equal "Куда продать %s: Терапевт - 39254 ₽, Миротворец - 203 $", p(Common.method(:parse_response).(File.read "cat.htm"))
  end

end

describe "integration1" do

  it do
    assert_match /\AКуда продать \"Статуэтка кота\": Терапевт - \d+ ₽, Миротворец - \d+ \$\z/, p(Common.price("кот"))
fail unless "\"Защищенный контейнер \\\"Каппа\\\"\" не продать" == p(Common.price("каппа"))
fail unless "can't find \"Бутылка водки \\\"Тарковская\\\"\"" == p(Common.price("тарковская"))  # the website is stupid about quotes
  end

end

require "nakiircbot"
describe "unit2" do

  it "track" do
    negative = <<~HEREDOC.split(?\n).each do |line|
      что за трек был?
      Ого что за трэк в 2023)
      Скинь трек предыдущий
      потом на странице гугла ткнул в расширение, чтоб убедиться, что оно видит, что за трек
      Ну что за песня Рэн... 10 часов подряд пожалуйста
      Что за песня при рейде звучит?
      Лер, что за песня была?
    HEREDOC
      refute Common.is_asking_track(line), line
    end
    positive = <<~HEREDOC.split(?\n).each do |line|
      @VELLREIN Кинь плз в чат ссылку на трэк
      @VELLREIN а что это за чудесная музыка играет?
      @ta_samaya_lera привет че за трек ? качает)
      @tot_samyi_denis_ че за песня
      веоик что за песня
      велик что за песня?
      ВЕЛИК ЧТО ЗА ПЕСНЯ
      Реня скинь пожалуйста этот трек который играл
      Музыка заставляет вслушиваться в слова)) что за трек))
      Уаааая что за песня такая , ашалеееть машала
      Ооо музыка топ можно трек ?)
      катя что за трек, голос у девки приятный
      как трек называется ,срочно дайте дайте!
      тёть Лер, а что за трек играет? Kappa
      а что за трек ? не успел зашазамить
      скинь этот трек название
      А можно трек? Что в донате
      Дайте трек пожалуйста
      че за депресивный трек
      А можно трек мне пожалуйста?
      а можно название трека?))
      а можно название трека?)
      можно трэк пожалйста?
      Можно трек?
      можно трек
      Ого, а можно трек ?
      как трек называется?
      ой а чо это за музыка...
      чо за музыка
      что за музыка?
      Что за музыка?
      Чо за музыка
      Что это за музыка NotLikeThis
      Что за трек сейчас играет?
      что за трек? скинь название
      Можно название трека?
      блин чо за трек
      А что за трек?
      а чё за трек?
      Что за трек ?
      Что за трек?
      что за трек?
      что за трек
      чё за трек?
      чо за трек
      че за трек?)
      ух чо затрэк
      Скинь трэк)
      Скинь трек )
      чо за песня
      что за песня
      что за песня?
      Что за песня ?
      а что за песня
      Что это за песня
      чё за песня играет?
      че за песня молодости
      Ктото скажет чё за песня ?
      А я даже не вкурсе что за песня
      Выпий суп паёк/? Что за песня такая
    HEREDOC
      assert Common.is_asking_track(line), line
    end
    Dir.glob("vps_logs/txt.*").sort.each do |path|
      puts path
      filename = "cache/#{File.basename path}.marshal"
      ( if File.exist? filename
        Marshal.load File.binread filename
      else
        NakiIRCBot.parse_log(path, "velik_bot").tap do |_|
          File.binwrite filename, Marshal.dump(_)
        end
      end.map do |line|
        line[4] if "PRIVMSG" == line[2]
      end.compact - positive ).each do |line|
        refute Common.is_asking_track(line), line
      end
    end
  end

  it "rep" do
    Common.instance_variable_get(:@repdb).transaction{ |db| db.roots.each &db.method(:delete) }
    Common.rep_plus "#channel", "user1", "user1"
    Common.rep_plus "#channel", "user1", "user2"
    Common.rep_minus "#channel", "user1", "user2"
    Time.stub(:now, Time.now + 90000){ Common.rep_plus "#channel", "user1", "user2" }
    assert_equal "@user1's current rep is 0 (top-2)", Common.rep_read_precise("#channel", "user1")
    assert_equal "@user2's current rep is 2 (top-1)", Common.rep_read("#channel", "user2")
    Common.rep_minus "#channel", "channel", "user2"
    Common.rep_minus "#channel", "channel", "user2"
    assert_equal "@user2's current rep is 0 (top-1)", Common.rep_read("#channel", "ser2")
  end

  # str, add_to_queue, restart_with_new_password, who, where, what
  it "loop" do
    e = []
    prev = Thread.list.size
    File.write "dynamic.cfg.yaml", ""
    File.write "quotes.yaml", ""
    NakiIRCBot.define_singleton_method :start do |*, &b|
      t = []; b.call nil, ->__,_{t<<_}, nil,  "",      "#channel", "\\?"       ; e.push [t.dup, "\\?", [/\Aдоступные команды: \\.+ -- используйте \\\? <команда> для получения справки по каждой\z/]]
      t = []; b.call nil, ->__,_{t<<_}, nil,  "",      "#channel", "\\? \\?"   ; e.push [t.dup, "\\? \\?", ["\\?, \\h, \\help [<команда>] - узнать все доступные команды или получить справку по указанной"]]
      t = []; b.call nil, ->__,_{t<<_}, nil,  "",      "#channel", "\\? ?"     ; e.push [t.dup, "\\? ?", [/\Aя не знаю команду \?, я знаю только: \\.+/]]
      t = []; b.call nil, ->__,_{t<<_}, nil,  "",      "#channel", "\\song"    ; e.push [t.dup, "\\song -интегр -верх -русс +song", ["no integration with #channel"]]
      t = []; b.call nil, ->__,_{t<<_}, nil,  "", "#nekochan_myp", "чо за трек"; e.push [t.dup, "\\song -интегр +верх +русс -song", [/отображается/]]
      t = []; b.call nil, ->__,_{t<<_}, nil,  "", "#nekochan_myp", "."         ; e.push [t.dup, "\\song -интегр +верх -русс -song", []]
      t = []; b.call nil, ->__,_{t<<_}, nil,  "", "#korolikarasi", "."         ; e.push [t.dup, "\\song +интегр -верх -русс -song", []]
      t = []; b.call nil, ->__,_{t<<_}, nil,  "", "#korolikarasi", "чо за трек"; Timeout.timeout(10){ sleep 0.5 until prev + 1 == Thread.list.size }; e.push [t.dup, "\\song +интегр -верх +русс -song", [/🎶/]]   # +1 is a Timeout thread itself
      t = []; b.call nil, ->  *_{t<<_}, nil, "name", "#channel",      "_ _K0PAC_ ░█▄▀▐▌" ; e.push [t.dup, "карась", []]
      t = []; b.call nil, ->  *_{t<<_}, nil, "name", "#korolikarasi", "_ _карас_ _" ; e.push [t.dup, "самокарась", []]
      [
        [Date.new, "name", "#channel", "Стасик Тайчин", "reference"],
        [Date.new+1, "name", "#channel", "Радик Бритва", "different date"],
        [Date.new, "name0", "#channel", "Сергей Погон", "different name"],
        [Date.new, "name", "#channel0", "Стасик Тайчин", "different channel"],
        [Date.new, "NAME", "#channel", "Стасик Тайчин", "capslock"],
      ].each do |date, who, where, name, test|
        Date.stub :today, date do
          t = []; b.call nil, ->__,_{t<<_}, nil, who, where, "\\ктоя" ; e.push [t.dup, "\\ктоя #{test}", [/\) #{who} -- #{name}\z/]]
        end
      end
      [
        ["#channel", "name",    "empty random",     "\\q",                 "no quotes yet, go ahead and use '\\qadd <text>' to add some!"],
        ["#channel", "name",    "empty index",      "\\q 1",               "no quotes yet, go ahead and use '\\qadd <text>' to add some!"],
        ["#channel", "name",    "empty search",     "\\q a",               "no quotes yet, go ahead and use '\\qadd <text>' to add some!"],
        ["#channel", "name",    "del denied",       "\\qdel 1",            "only channel owner add those added using \\access_quote are allowed to add quotes"],
        ["#channel", "name",    "access denied",    "\\access_quote name", "only channel owner can toggle \\qadd and \\qdel access"],
        ["#channel", "channel", "access 1",         "\\access_quote name", "added \\qadd and \\qdel access for \"name\""],
        ["#channel", "name",    "empty del",        "\\qdel 1",            "quote #1 not found"],
        ["#channel", "channel", "access 2",         "\\access_quote name", "removed \\qadd and \\qdel access for \"name\""],
        ["#channel", "name",    "del denied again", "\\qdel 1",            "only channel owner add those added using \\access_quote are allowed to add quotes"],
        ["#channel", "name",    "add denied",       "\\qadd 1",            "only channel owner add those added using \\access_quote are allowed to add quotes"],
        ["#channel", "channel", "access 3",         "\\access_quote name", "added \\qadd and \\qdel access for \"name\""],
        ["#channel", "name",    "add a b",          "\\qadd a b",          "quote #1 added"],
        ["#channel", "channel", "add c d",          "\\qadd c d",          "quote #2 added"],
        ["#channel", "name",    "add e f",          "\\qadd e f",          "quote #3 added"],
        ["#channal", "channal", "add elsewhere",    "\\qadd i j",          "quote #1 added"],
        ["#channel", "name",    "del 1",            "\\qdel 1",            "quote #1 deleted"],
        ["#channel", "name",    "del два",          "\\qdel два",          "bad index \"два\", must be a natural number"],
        ["#channel", "name",    "add g h",          "\\qadd g h",          "quote #4 added"],
        ["#channel", "name",    "del 3",            "\\qdel 3",            "quote #3 deleted"],
        ["#channel", "name",    "index 4",          "\\q 4",               "#4: g h"],
        ["#channel", "name",    "index 3",          "\\q 3",               "quote #3 not found"],
        ["#channel", "name",    "index 2",          "\\q 2",               "#2: c d"],
        ["#channel", "name",    "index 1",          "\\q 1",               "quote #1 not found"],
        ["#channel", "name",    "search",           "\\q ai dj",           "#2: c d"],
        # ["#channel", "name", "random"], # TODO
      ].each do |where, who, test, cmd, *expectation|
        where = where.chars.map{ |c| [c, c.upcase].sample }.join
        who   = who.  chars.map{ |c| [c, c.upcase].sample }.join
        t = []
        b.call nil, ->__,_{t<<_}, nil, who, where, cmd
        e.push [t.dup, "access,quote :: #{test}", expectation]
      end
    end
    require_relative "main"
    e.each do |r, t, e|
      assert_equal e.size, r.size, t
      [e, r].transpose.each{ |e, r| assert_operator e, :===, r, "test: #{t.inspect}" }
    end
  end

end

describe "integration2" do
  it "clip" do
    assert_equal "https://clips.twitch.tv/RichProtectiveOcelotNotATK-6MH7oHRTHSk1lzuh", Common.clip("korolikarasi", "человекдерево")
  end
end

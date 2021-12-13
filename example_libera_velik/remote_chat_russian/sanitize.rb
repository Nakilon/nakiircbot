nicknames = {}

lenta_sanitize = lambda do |_|
  _.delete("\uFEFF\u007F\u2028\u0306\u200D\u0336\u200E").
    tr('—–­─‑','-').tr('   ​ʼ’`‘´“”″„«»','    \'\'\'\'\'""""""').
    gsub("''",'"').gsub("…","...").
    strip.squeeze(' "')
end

require "ruby-progressbar"
using ProgressBar::Refinements::Enumerator

require "date"
valid = '- "`#a-zA-Zа-яА-ЯёЁ0-9.,?¿!:;()[]{}<>@$€%^&_+±=≈~*×°²¼µ™¶√№♥•∙·☺©®≥≤÷|/\\\\\'' + ?\n
invalid = "\u0001\u0002\u000E\u0011\u0003\u0013\u0014\u0018\u001E\u001C\u001D\u0012\u001A\u0015\u0010\u0017\u007F\u0092\u0094\u0081\u07B3"\
          "\b\f�╓╕═╤╖╜│╧╦┌╥└╩╚╟╢╘╝┘░┐╣╫╡╬╠╨■▄▀┼┤┴╞▐╒▒▌▓█╛╪║├╙┬╗╔"
[
  *Dir.glob("irc.linsovet.org.ua/logs/linux_raw.old/*/*").map{ |_| [_,_[-9,9]] },
  *Dir.glob("irc.linsovet.org.ua/logs/linux_raw/linux.log.*.txt").map{ |_| [_,_[-13,9]] },
].sort_by do |filename, day|
  fail filename unless /\A\d\d[A-Z][a-z][a-z]20\d\d\z/ =~ day
  Date.strptime $&, "%d%b%Y"
end.group_by{ |_, day| day[2..-1] }.each.with_progressbar do |month, group|
  next if File.exist? "sanitized/#{month}.txt"
  text = group.map{ |filename, day| lenta_sanitize[File.read(filename).scrub.tr("\t "," ")].gsub(/^/, "#{day[0,2]} ") + ?\n }.join
  p [
    month,
    text.dup.delete(invalid).gsub(/[\p{Han}\p{Thaana}\p{Katakana}\p{Greek}\p{Hiragana}]+/,"").size,
    text.dup.delete(valid).size,
    text.dup.delete(valid+invalid).gsub(/[\p{Han}\p{Thaana}\p{Katakana}\p{Greek}\p{Hiragana}]+/,"").chars.group_by(&:itself).map{ |_, g|
      [_, _.dump, g.size]
    }.sort_by(&:last).reverse,
  ]
  File.write "sanitized/#{month}.txt", text.scan(/.+\n/).map.reject{ |_| _.dup.delete! ?^+valid }.join
end

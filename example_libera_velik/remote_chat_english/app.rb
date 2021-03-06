require "functions_framework"

require_relative "common"

FunctionsFramework.http do |request|
  s = JSON.load request.body.read
  fail unless s.encoding.to_s == "UTF-8"


  # copypasted from my NLP project private repo

  line = s.scrub.tr("\t"," ").delete('^- /\\\'"`#a-zA-Z0-9.,?!:;()[]{}<>@$%^&_+=*|~☺'+?\n).strip.
    gsub(/(?<=\A|\s):-?[()|\\\/PD](?=\z|\s)/, "☺").
    gsub(/(?<=[^\s"])"(?=\z|[^"a-z])/i, ' \0').
    gsub(/(?<=[^\s'])'(?=\z|[^'a-z])/i, ' \0').
    gsub(/(?<=\A|[^"a-z])"(?=[^\s"])/i, '\0 ').
    gsub(/(?<=\A|[^'a-z])'(?=[^\s'])/i, '\0 ').
    gsub(/(?<=[^\s(])\)(?=\z|\s)/, ' )').
    gsub(/(?<=\A|\s)\((?=[^\s)])/, '( ').
    gsub(/(?<=[^\s\[])\](?=\z|\s)/, ' ]').
    gsub(/(?<=\A|\s)\[(?=[^\s\]])/, '[ ').
    gsub(/(?<=[^\s{])\}(?=\z|\s)/, ' }').
    gsub(/(?<=\A|\s)\{(?=[^\s}])/, '{ ').
    gsub(/(?<=\S)'s been(?=\z|\s)/i, " has been").
    gsub(/(?<=\A|\s)can't(?=\z|\s)/i, "can not").
    gsub(/(?<=\A|\s)(do|does|did|have|is|was|are|would|could)n't(?=\z|\s)/i, '\1 not').
    gsub(/(?<=\A|\s)(you|they)'re(?=\z|\s)/i, '\1 are').
    gsub(/(?<=\A|\s)i'm(?=\z|\s)/i, "I am").
    gsub(/(?<=\A|\s)(i|you)'ll(?=\z|\s)/i, '\1 will').
    gsub(/(?<=\A|\s)(that|you)'d(?=\z|\s)/i, '\1 would').
    gsub(/(?<=\A|\s)(i|you|we|they)'ve(?=\z|\s)/i, '\1 have').
    gsub(/(?<=\A|\s)(it|where|there|that|what)'s(?=\z|\s)/i, '\1 is').
    gsub(/(?<=\A|\s)(\S+)'s(?=\z|\s)/i, '\1 \'s').
    strip.

    gsub(/(?<=[^\s<])>(?=\z|\s)/, ' >').
    gsub(/(?<=\A|\s)<(?=[^\s>])/, '< ')

  line = Common.insert_spaces line

  next "" unless line[" "]


  emit = Enumerator.new do |e|
    loop do
      t = Common::Nov2021.pick(line).
        gsub(/((?:\.\.\.|[.?!]) )(.)/){ "#{$1}#{$2.upcase}"}.
        gsub(/\b(a) ([eyuioa])/i, '\1n \2').
        gsub(/\b(a)n ([^eyuioa])/i, '\1 \2').
        gsub(" 's ", "'s ").
        gsub(/(?<=\A|\s)(['"]) (.*?) ?\1/, '\1\2\1').
        gsub(/(?<=\A|\s)\( (.*?) ?\)/, '(\1)').
        gsub("s's", "s'").
        gsub(/(?<=\A|\s)(is|do|did|have) not(?=\z|\s)/, '\1n\'t').
        gsub(/(?<=\A|\s)I am(?=\z|\s)/, "I'm").
        gsub(/(?<=\A|\s)it is(?=\z|\s)/, "it's").
        gsub(/ (\.\.\.|[:,.?!])/, '\1').
        gsub("☺", ":#{?- if rand(2).zero?}#{%w{ ( ) | \\ / P D }.sample}")
      e << t if t.count(" ") > 1 && t.size <= 150
    end
  end


  require "damerau-levenshtein"
  variant = emit.take(10).min_by do |variant|
    DamerauLevenshtein.distance line.downcase.split.sort.join, variant.downcase.split.sort.join
  end

  variant
end

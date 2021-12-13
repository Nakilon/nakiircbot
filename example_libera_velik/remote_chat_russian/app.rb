require "functions_framework"

require_relative "common"

FunctionsFramework.http do |request|
  s = JSON.load request.body.read
  fail unless s.encoding.to_s == "UTF-8"


  line = Common::lenta_sanitize(s.scrub.tr("\t"," ")).
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
    strip.

    gsub(/(?<=[^\s<])>(?=\z|\s)/, ' >').
    gsub(/(?<=\A|\s)<(?=[^\s>])/, '< ')

  line = Common.insert_spaces line

  next "" unless line[" "]  # I don't remember why but we ignore one word triggers


  emit = Enumerator.new do |e|
    loop do
      t = Common::Dec2021.pick(line).
        gsub(/((?:\.\.\.|[.?!]) )(.)/){ "#{$1}#{$2.upcase}"}.
        gsub(/(?<=\A|\s)(['"]) (.*?) ?\1/, '\1\2\1').
        gsub(/(?<=\A|\s)\( (.*?) ?\)/, '(\1)').
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

# copypasted from my NLP project private repo

module Common

  module Sep2021

  def self.read_mmul text
    text.map do |real, markup|
      fail real unless real.count('^- /\\\'"`#a-zA-Z0-9.,?!:;()[]{}<>@$%^&_+=*|~☺'+?\n).zero?  # we check the alphabet again because the input may be handcrafted
      [
        *markup.to_enum(:scan, /(^| )(\S+)/).map{ |pre, type| [($`+pre).size, type] }, [1]
      ].each_cons(2).with_index.map do |((p1, type), (p2, *)), i|
        [real[p1..p2-2].strip, type, i]
      end
    end
  end
  @@words = {}
  @@sentences = []
  def self.learn_sentences_and_words file
    read_mmul(File.read(file).split("\n").each_slice(2)).each do |line|
      @@sentences.push( line.map do |word, type, i|
        @@words[type] ||= []
        @@words[type].push [word, i]
        type
      end )
    end
  end

    def self.learn
      %w{ train.2021-01.txt train.2021-02.txt }.each &method(:learn_sentences_and_words)
      learn_words = lambda do |slices|
        read_mmul(slices).each do |line|
          line.each do |word, type, i|
            @@words[type] ||= []
            @@words[type].push [word, i]
            type
          end
        end
      end
      learn_words.call %w{ 2020-12.tree-tagger.txt 2021-01.tree-tagger.txt 2021-02.tree-tagger.txt }.
        flat_map{ |filename| File.read(filename).split("\n") }.each_slice(2)
    end
    def self.pick
      @@sentences.sample.reject do |type|
        rand(2).zero? if %w{ not oh }.include? type
      end.map.with_index do |type, i|
        next if i.zero? && %w{ ! : , }.include?(type)
        @@words.fetch(type).
        sample[0]
      end.compact
    end

  end if false

  module Module_get_key
    private
    def get_key context, i
      _, word, _, parent, label, tag, morph = context[i]
      [
        label, tag,
        (word if tag == "PUNCT"),
        ([label, tag] == ["AUX", "VERB"] && context[parent][4,2] == ["ROOT", "VERB"] && context[parent][-1]["tense"] == "PRESENT"),
        ([label, tag] == ["AUX", "VERB"] && morph["mood"] == "INDICATIVE" && context[parent][4,2] == ["ROOT", "VERB"]),
        ([label, tag] == ["ROOT", "VERB"] && parent == i && morph["person"] == "THIRD"),
        ([label, tag] == ["ROOT", "VERB"] && parent == i && context.any?{ |_, word, _, parent,| word == "there" && parent == i }),
        ([label, tag] == ["MARK", "ADP"] && context[parent][4,2] == ["ADVCL", "VERB"]),
        ([label, tag] == ["NSUBJ", "PRON"] && morph["person"] == "THIRD"),
        ([label, tag] == ["NSUBJ", "NOUN"] && context[parent][4,2] == ["ROOT", "VERB"] && context[parent][-1]["person"] == "THIRD"),
        ([label, tag] == ["DOBJ", "PRON"] && morph["case"] == "ACCUSATIVE" && context[parent][4,2] == ["ROOT", "VERB"]),
        ([label, tag] == ["ADV", "ADVMOD"] && context[parent][4,2] == ["ROOT", "VERB"]),
        ([label, tag] == ["NSUBJ", "PRON"] && context[parent][4,2] == ["RCMOD", "VERB"] && context[parent][-1]["person"] == "THIRD"),
      ]
    end
  end
  private_constant :Module_get_key

  module Oct2021
    extend Module_get_key
    class << self
      def pick_for_chat
        words = @@all.sample.drop(1)
        words.size.times.map{ |i| @@knowledge.fetch(get_key words, i).sample }
      end
      def pick_and_print
        words = @@all.sample.tap{ |_| _.each &method(:p) }.drop(1)
        puts words.size.times.map{ |i| @@knowledge.fetch(get_key words, i).sample }.join " "
      end
    end

    require "json/pure"
    @@all = (
      File.read("2020-12.jsonl") +
      File.read("2021-01.jsonl")
    ).split("\n").map(&JSON.method(:load)).reject{ |_, *words| words.any?{ |_, word,| %w{ 's dont }.include? word } }
    puts "loaded #{@@all.size}"
    @@knowledge = {}
    @@all.each do |_, *words|
      words.size.times do |i|
        key = get_key words, i
        @@knowledge[key] ||= []
        @@knowledge[key].push words[i][1]
      end
    end
  end if false

  module Nov2021
    extend Module_get_key

    if File.exist? "cache.marshal"
      @@all, @@vocabulary, @@word2lemma, @@contexts = Marshal.load(File.read "cache.marshal")
    else
      require "json/pure"
      @@all = (
        File.read("2020-12.jsonl") +
        File.read("2021-01.jsonl")
      ).split("\n").map(&JSON.method(:load)).
        reject{ |_,| _[/\Ao O \( /] }.
        reject{ |_, *words| words.any?{ |_, word,| %w{ 's dont }.include? word } }
      @@vocabulary = {}
      @@word2lemma = {}
      @@contexts = {}
      @@all.each do |_, *words|
        lemmas = words.map.with_index do |word, i|
          key = get_key words, i
          @@vocabulary[key] ||= []
          @@vocabulary[key].push word[1].sub /\A[A-Z][a-z]/, &:downcase
          @@word2lemma[word[1].downcase] = word[2]
        end.uniq
        lemmas.each do |l1|
          lemmas.each do |l2|
            next if l1 == l2
            @@contexts[l1] ||= {}
            @@contexts[l1][l2] ||= 0
            @@contexts[l1][l2] += 1
          end
        end
      end
      File.write "cache.marshal", Marshal.dump([@@all, @@vocabulary, @@word2lemma, @@contexts])
    end
    puts "jsons: #{@@all.size}"
    puts "vocabulary: #{@@vocabulary.size}"
    puts "words: #{@@word2lemma.size}"
    puts "lemmas: #{@@contexts.size}"

    class << self
      def pick input_line, print = false
        words = @@all.sample.tap{ |_| _.each &method(:p) if print }.drop(1)
        context = input_line.downcase.split.uniq.map{ |_| @@contexts[@@word2lemma[_]] }.compact
        words.size.times.map do |i|
          candidates = {}
          add = ->_,n=1{ candidates[_] = (candidates[_] || 0) + n }
          @@vocabulary.fetch(get_key words, i).each do |var|
            add[var]
            context.each{ |c| n = c[@@word2lemma[var]] and add[var, n] }
          end
          max = candidates.values.max
          t = candidates.flat_map{ |k,v| [k]*(v*100/max) }.sample
          t == ?i ? ?I : t
        end.join " "
      end
    end
  end

  def self.insert_spaces s
    s.
    gsub(/(\.\.\.|[;:,.?!])/i, ' \0'). # need \A| here because the case of leading '...'
    gsub(/(\.\.\.|[;:,.?!]) ?/, '\1 ').
    squeeze(" ").strip
  end

end

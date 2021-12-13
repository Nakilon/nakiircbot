module Common

  module Module_get_key_russian
    private
    def get_key context, i
      # don't forget to purge the cache.marshal
      _, word, _, parent, label, tag, morph = context[i]
      [
        label, tag,
        (word if tag == "PUNCT"),
        ([label, tag] == ["PRECONJ", "CONJ"] && morph["proper"] == "NOT_PROPER" && word),
        ([label, tag] == ["CC", "CONJ"]      && morph["proper"] == "NOT_PROPER" && word),
        ([label, tag] == ["DISCOURSE", "X"]  && morph["proper"] == "NOT_PROPER" && word),
        ([label, tag] == ["PREP", "ADP"]     && morph["proper"] == "NOT_PROPER" && word),   # child may depend on this word for correct morph["case"]
        ([label, tag] == ["POBJ", "NOUN"]    && context[parent][5] == "ADP" && context[parent][1]),
        ([label, tag] == ["POBJ", "PRON"]    && context[parent][5] == "ADP" && context[parent][1]),
        ([label, tag] == ["NSUBJ", "PRON"]   && context[parent][5] == "VERB" && context[parent][-1]["person"] == "THIRD"),
        ([label, tag] == ["DOBJ", "NOUN"]    && context[parent][4,2] == ["ROOT",  "VERB"] && morph["case"] == "DATIVE"),
        ([label, tag] == ["NSUBJ", "PRON"]   && context[parent][4,2] == ["ROOT",  "VERB"] && context[parent][-1]["person"] == "THIRD"),
        ([label, tag] == ["NSUBJ", "NOUN"]   && context[parent][4,2] == ["ROOT",  "VERB"] && context[parent][-1]["number"]),
        ([label, tag] == ["NSUBJ", "PRON"]   && context[parent][4,2] == ["RCMOD", "VERB"] && context[parent][-1]["number"]),
        ([label, tag] == ["NUM", "NUM"]      && context[parent][4,2] == ["DOBJ",  "NOUN"] && context[parent][-1]["number"]),
        ([label, tag] == ["AMOD", "ADJ"]     && context[parent][4,2] == ["APPOS", "NOUN"] && context[parent][-1]["number"]),
        ([label, tag] == ["DET", "DET"]      && context[parent][4,2] == ["POBJ",  "NOUN"] && context[parent][-1]["case"]),
        ([label, tag] == ["POSS", "PRON"]    && context[parent][4,2] == ["POBJ",  "NOUN"] && context[parent][-1]["case"]),
        ([label, tag] == ["AMOD", "ADJ"]     && context[parent][4,2] == ["ROOT",  "NOUN"] && context[parent][-1]["gender"]),
        ([label, tag] == ["XCOMP", "VERB"]   && context[parent][4,2] == ["ROOT",  "VERB"] && !!context[parent][-1]["tense"]),
        ([label, tag] == ["XCOMP", "VERB"]   && context[parent][4,2] == ["ROOT",  "VERB"] && context[parent][1] == "давайте"),
        ([label, tag] == ["GMOD", "NOUN"]    && context[parent][4,2] == ["ROOT",  "NOUN"] && context[parent][1] == "причина"),
        ([label, tag] == ["NSUBJ", "PRON"]   && context[parent][4,2] == ["CCOMP", "VERB"] && !!context[parent][-1]["tense"]),
        ([label, tag] == ["AMOD", "ADJ"]     && context[parent][4,2] == ["ADVCL", "NOUN"] && context[parent][-1]["gender"] == "FEMININE"),
        ([label, tag] == ["PARATAXIS", "VERB"] && context[parent][4,2] == ["ROOT",  "VERB"] && context[parent][-1].values_at("number", "person")),
        ([label, tag] == ["NSUBJ", "PRON"]   && context[context[parent][3]][-1]["number"]),
        # ([label, tag] == ["ROOT", "VERB"] && parent == i && context.any?{ |_, word, _, parent,| word == "there" && parent == i }),
      ]
    end
  end
  private_constant :Module_get_key_russian

  module Dec2021
    extend Module_get_key_russian

    if File.exist? "cache.marshal"
      @@all, @@vocabulary, @@word2lemma, @@contexts = Marshal.load(File.read "cache.marshal")
    else
      require "json/pure"
      @@all = (
        File.read("Aug2005-1.jsonl")
      ).split("\n").map(&JSON.method(:load)).
        select{ |_,| _[" "] }.
        reject{ |_,| _[/[a-z]/i] }
        #reject{ |_, *words| words.any?{ |_, word,| %w{  }.include? word } }
      @@vocabulary = {}
      @@word2lemma = {}
      @@contexts = {}
      @@all.each do |_, *words|
        lemmas = words.map.with_index do |word, i|
          key = get_key words, i
          @@vocabulary[key] ||= []
          @@vocabulary[key].push word[1].sub /\A[А-ЯЁA-Z][а-яёa-z]/, &:downcase
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
        context = input_line.downcase.split.uniq.map{ |_| @@contexts[@@word2lemma[_]] }.compact
        p context.map(&:size)
        words = @@all.sample.tap{ |_| _.each &method(:p) if print }.drop(1)
        words.size.times.map do |i|
          p get_key(words, i)
          candidates = {}
          add = ->_,n=1{ candidates[_] = (candidates[_] || 0) + n }
          @@vocabulary.fetch(get_key words, i).each do |var|
            add[var]
            context.each{ |c| n = c[@@word2lemma[var]] and add[var, n] }
          end
          max = candidates.values.max
          t = candidates.flat_map{ |k,v| [k]*(v*100/max) }.sample
          # t == ?i ? ?I : t
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

  def self.lenta_sanitize _
    _.delete("\uFEFF\u007F\u2028\u0306\u200D\u0336\u200E").
      tr('—–­─‑','-').tr('   ​ʼ’`‘´“”″„«»','    \'\'\'\'\'""""""').
      gsub("''",'"').gsub("…","...").
      strip.squeeze(' "')
  end

end

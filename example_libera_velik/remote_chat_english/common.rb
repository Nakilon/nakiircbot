# copypasted from my NLP project private repo

module Common

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

  def self.insert_spaces s
    s.
    gsub(/(\.\.\.|[;:,.?!])/i, ' \0'). # need \A| here because the case of leading '...'
    gsub(/(\.\.\.|[;:,.?!]) ?/, '\1 ').
    squeeze(" ").strip
  end

end

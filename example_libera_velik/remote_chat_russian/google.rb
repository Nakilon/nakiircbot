require "pp"
require "json"
require "nakischema"
json = JSON.load STDIN.read

assert_equal = lambda do |a, b|
  next true if a == b
  STDERR.puts "#{a.inspect} != #{b.inspect}"
  abort
end

acc = 0
content = [/\A\S+\z/, "' '", ". .", ".. .", ".. ...", "e s", "1 - 1", "1 - 10", "5 - 7", "6600 - 20", "5 170", "25 200", "49 000", "49 800", /\A[12] \d\d0 000\z/]
json["tokens"].drop(0).
               chunk.with_index do |token, i|
  # STDERR.puts "token ##{i}"
  Nakischema.validate token, {
    hash: {
      "dependencyEdge" => {hash: {
        "headTokenIndex" => 0..100000,
          # CSUBJPASS    CSUBJ
          #  PS   PREDET PCOMP PRT    TITLE  VMOD
        "label" => %w{
          ADVCL ACOMP ATTR APPOS AUX AUXPASS ADVMOD AMOD
          CC CCOMP CONJ DISCOURSE DEP DET DOBJ EXPL GMOD GOESWITH INFMOD IOBJ LIST MWE MARK
          NN NSUBJPASS NPADVMOD NUM NUMBER NEG NSUBJ
          P POBJ PARATAXIS PARTMOD POSS PREP PRECONJ
          REMNANT ROOT RCMOD TMOD XCOMP
        },
      } },
      "lemma" => content,
      "partOfSpeech" => {hash: {
        "aspect"      => %w{ ASPECT_UNKNOWN IMPERFECTIVE PERFECTIVE },
        "case"        => %w{ CASE_UNKNOWN ACCUSATIVE DATIVE GENITIVE INSTRUMENTAL LOCATIVE NOMINATIVE PARTITIVE PREPOSITIONAL VOCATIVE },
        "form"        => %w{ FORM_UNKNOWN LONG SHORT },
        "gender"      => %w{ GENDER_UNKNOWN FEMININE MASCULINE NEUTER },
        "mood"        => %w{ MOOD_UNKNOWN IMPERATIVE INDICATIVE },
        "number"      => %w{ NUMBER_UNKNOWN PLURAL SINGULAR },
        "person"      => %w{ PERSON_UNKNOWN FIRST SECOND THIRD REFLEXIVE_PERSON },
        "proper"      => %w{ PROPER_UNKNOWN PROPER NOT_PROPER },
        "reciprocity" => "RECIPROCITY_UNKNOWN",
        "tag"         => %w{ ADJ ADP ADV CONJ DET NOUN NUM PRON PRT PUNCT VERB X },
        "tense"       => %w{ TENSE_UNKNOWN FUTURE PAST PRESENT },
        "voice"       => %w{ VOICE_UNKNOWN ACTIVE PASSIVE },
      } },
      "text" => {hash: {
        "beginOffset" => 0..1000000,
        "content" => content,
      } },
    },
  }
  json["sentences"].take_while{ |_| _["text"]["beginOffset"] <= token["text"]["beginOffset"] }.size - 1
end.#drop(600).
# end.#to_a.
    map do |index, chunk|  # TODO: assert index being incremented by +1
  STDERR.puts "sentence ##{index}"
# STDERR.puts chunk.inspect
  fail unless assert_equal.call json["sentences"][index]["text"]["content"].delete(" "), chunk.map{ |token| token["text"]["content"] }.join.delete(" ")
  Nakischema.validate json["sentences"][index], {
    hash: {
      "text" => {hash: {
        "beginOffset" => 0..1000000,
        "content" => /\A\S(.*\S)?\z/,
      } },
    },
  } unless ENV["SKIP_VALIDATION"]
  offset = json["sentences"][index]["text"]["beginOffset"]
  chunk.each do |token|
    token["dependencyEdge"]["headTokenIndex"] -= acc
    token["text"]["beginOffset"] -= offset
    token["partOfSpeech"].delete_if{ |k,v| v[/_UNKNOWN\z/] }
  end
  acc += chunk.size
  # pp chunk
  # next
  [json["sentences"][index], chunk]   # we split in .map and .each because we mutate the sentence that is used above as .take_while{...}.size
end.each do |sentence, chunk|
  # p sentence
  puts JSON.dump [
    sentence["text"]["content"],
    *chunk.map{ |token|
      [
        *token["text"].values,
        token["lemma"],
        *token["dependencyEdge"].values,
        token["partOfSpeech"].delete("tag"),
        token["partOfSpeech"],
      ]
    },
  ]
end

Gem::Specification.new do |spec|
  spec.name         = "nakiircbot"
  spec.version      = "0.1.3"
  spec.summary      = "IRC bot framework"

  spec.author       = "Victor Maslov aka Nakilon"
  spec.email        = "nakilon@gmail.com"
  spec.license      = "MIT"
  spec.metadata     = {"source_code_uri" => "https://github.com/nakilon/nakiircbot"}

  spec.required_ruby_version = ">=2.5"  # at least for Exception#full_message and block rescue

  spec.files        = %w{ LICENSE nakiircbot.gemspec lib/nakiircbot.rb }
end

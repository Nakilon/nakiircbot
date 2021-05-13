def ping_command_processor str, add_to_queue
  return unless /\A(?<tags>\S+) :(?<who>[^!]+)!\S+ PRIVMSG (?<where>\S+) :(?<what>.+)/ =~ str
  return unless where == "#nakilon"
  add_to_queue.call where, "pong!" if what.downcase == "?ping"
end

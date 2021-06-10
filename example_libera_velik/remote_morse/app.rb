require "functions_framework"
require "morsify"

FunctionsFramework.http "morse" do |request|
  input = JSON.load request.body.read   # JSON.load makes .encoding="utf-8"
  Morsify.encode(input).gsub(" "*7, " / ").squeeze(" ")
end
FunctionsFramework.http "demorse" do |request|
  input = JSON.load request.body.read   # JSON.load makes .encoding="utf-8"
  input = input.gsub(/ *\/ */, " "*7)
  if input.start_with? "ru "
    Morsify.decode input[3..-1], :ru
  else
    Morsify.decode input
  end.encode("utf-8")
end

require 'json'
require 'net/http'
require_relative '../src/ecmongo.rb'
collection = ECMongo.getCollection("Teams")
teams = collection.find().to_a

for team in teams
    url = team["image"]
    url = url.gsub(/ /, "")
    team["image"] = url 
    collection.update_one({"_id" => team["_id"]}, team)
end



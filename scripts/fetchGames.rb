require 'json'
require 'net/http'
require 'uri'
require_relative '../src/ecmongo.rb'

url = URI.parse("http://api.football-data.org/v1/soccerseasons/424/fixtures")
req = Net::HTTP::Get.new(url.path)
req.add_field("X-Auth-Token", "8e4fb54a4f0e4717ad1e45e2abc2d2f6")
res = Net::HTTP.new(url.host, url.port).start do |http|
  http.request(req)
end

data = JSON.parse(res.body)

gameList = []

games = data["fixtures"]
collection = ECMongo.getCollection("Games")
for game in games
    gameObj = {}
    gameObj["_id"] = game["_links"]["self"]["href"].split("/").last
    gameObj["gameID"] = gameObj["_id"]
    gameObj["awayTeam"] = game["_links"]["awayTeam"]["href"].split("/").last
    gameObj["homeTeam"] = game["_links"]["homeTeam"]["href"].split("/").last
    status = game["status"]
    state = "progress"
    if status == "TIMED"
        state = "upcoming"
    elsif status == "FINISHED"
        state = "complete"
    end
    gameObj["state"] = state
    gameObj["startTime"] = DateTime.parse(game["date"]).to_time.to_i
    homeGoals = game["result"]["goalsHomeTeam"]
    awayGoals = game["result"]["goalsAwayTeam"]
    if homeGoals.nil?
        homeGoals = 0
    else 
        homeGoals = homeGoals.to_i
    end
    if awayGoals.nil?
        awayGoals = 0
    else 
        awayGoals = awayGoals.to_i
    end
    gameObj["awayGoals"] = awayGoals
    gameObj["homeGoals"] = homeGoals

    collection.update_one({"_id" => gameObj["_id"]}, gameObj, {:upsert => true})
end





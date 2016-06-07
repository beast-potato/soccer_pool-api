require 'json'
require 'net/http'
require_relative '../src/ecmongo.rb'

uri = URI('http://api.football-data.org/v1/soccerseasons/424/fixtures')
data = JSON.parse(Net::HTTP.get(uri))

gameList = []

games = data["fixtures"]
collection = ECMongo.getCollection("Games")
for game in games
    gameObj = {}
    gameObj["_id"] = game["_links"]["self"]["href"].split("/").last
    gameObj["gameID"] = gameObj["_id"]
    gameObj["awayTeam"] = game["_links"]["awayTeam"]["href"].split("/").last
    gameObj["homeTeam"] = game["_links"]["homeTeam"]["href"].split("/").last
    gameObj["startTime"] = Date.parse(game["date"]).to_time.to_i
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





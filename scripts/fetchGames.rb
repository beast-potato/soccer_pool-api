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
    startTime = DateTime.parse(game["date"]).to_time.to_i
    gameObj["startTime"] = startTime
    requiresWinner = false
    if (startTime > 1466622000)
    #if (startTime > 1466621000)
        requiresWinner = true
    end
    gameObj["requiresWinner"] = requiresWinner
    homeGoals = game["result"]["goalsHomeTeam"]
    awayGoals = game["result"]["goalsAwayTeam"]

    if !game["result"]["extraTime"].nil?
        result = game["result"]["extraTime"]
        homeGoals = result["goalsHomeTeam"].to_i
        awayGoals = result["goalsAwayTeam"].to_i
    end

    if !game["result"]["penaltyShootout"].nil?
        result = game["result"]["penaltyShootout"]
        if result["goalsHomeTeam"].to_i > result["goalsAwayTeam"].to_i
            homeGoals = homeGoals + 1
        end
        if result["goalsHomeTeam"].to_i < result["goalsAwayTeam"].to_i
            awayGoals = awayGoals + 1
        end
    end


    winner = "tie"
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
    if awayGoals > homeGoals
        winner = "awayTeam"
    end
    if awayGoals < homeGoals
        winner = "homeTeam"
    end

    gameObj["awayGoals"] = awayGoals
    gameObj["homeGoals"] = homeGoals

    gameObj["winner"] = winner
    collection.update_one({"_id" => gameObj["_id"]}, gameObj, {:upsert => true})
end





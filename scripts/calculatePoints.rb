require 'json'
require 'net/http'
require_relative '../src/ecmongo.rb'

gameList = []

gameCollection = ECMongo.getCollection("Games")
predictionCollection = ECMongo.getCollection("Predictions")

games = gameCollection.find().to_a
pointsHash = {}
currentTime = Time.now.to_i
for game in games
    if game["startTime"] > currentTime
        next
    end
    awayScore = game["awayGoals"].to_i
    homeScore = game["homeGoals"].to_i
    winner = "tie"
    if awayScore > homeScore
        winner = "away"
    end
    if awayScore < homeScore
        winner = "home"
    end
    predictions = predictionCollection.find({"gameID" => game["gameID"]})
    for prediction in predictions
        points = 0

        awayPrediction = prediction["awayGoals"].to_i
        homePrediction = prediction["homeGoals"].to_i

        winnerPrediction = "tie"
        if awayPrediction > homePrediction
            winnerPrediction = "away"
        end
        if awayPrediction < homePrediction
            winnerPrediction = "home"
        end

        if winnerPrediction == winner
            points += 2
        end
        if awayPrediction == awayScore
            points += 1
        end
        if homePrediction == homeScore
            points += 1
        end

        if points == 4
            points = 5
        end

        token = prediction["token"]
        if pointsHash[token].nil?
            pointsHash[token] = 0
        end
        previous = pointsHash[token]
        current = previous + points
        pointsHash[token] = current

        prediction["awayGoals"] = prediction["awayGoals"].to_i
        prediction["homeGoals"] = prediction["homeGoals"].to_i

        prediction["points"] = points
        predictionCollection.update_one({"_id" => prediction["_id"]}, prediction)
    end
end

pointsCollection = ECMongo.getCollection("Points")
pointsList = []
pointsHash.each do |key, value|
  point = {}
  point["_id"] = key
  point["points"] = value
  pointsList.push(point)
end

pointsCollection.drop()
pointsCollection.insert_many(pointsList)

updateCollection = ECMongo.getCollection("Updates")
updateCollection.insert_one({"time" => currentTime})

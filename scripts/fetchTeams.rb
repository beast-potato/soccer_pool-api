require 'json'
require 'net/http'
require_relative '../src/ecmongo.rb'


uri = URI('http://api.football-data.org/v1/soccerseasons/424/teams')
data = JSON.parse(Net::HTTP.get(uri))

teamList = []

teams = data["teams"]
for team in teams
	url = URI(team["crestUrl"])
    teamObj = {}
    teamObj["_id"] = team["_links"]["self"]["href"].split("/").last
    teamObj["name"] = team["name"]
    teamObj["image"] = "http://104.131.118.14/images/" + team["name"] + ".png"
    
    teamList.push(teamObj)
end

puts teamList

# drop collection and insert_many(teamList)
collection = ECMongo.getCollection("Teams")
collection.drop
collection.insert_many(teamList)


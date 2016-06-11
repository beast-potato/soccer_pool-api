get '/oleksiy' do
    "oleksiy eats too much salchicha! #NoGains"
end


get '/images/:filename' do
    puts "TESTING THIS VALUE"
    puts params["filename"]
    send_file File.join(settings.public_folder, 'images/' + params['filename'])
end

get '/info' do 
   send_file File.join(settings.public_folder, 'info.html')
end 

post '/login' do
    result = defaultResult()
    
    #validate params
    p = {}
    if defined? params
        p = params
    end
    
    email = p["email"]
    if email.nil?
        return Error(ECError["InvalidInput"], "'email' must not be nil")
    end
    email = email.downcase
#    if (!email.include?("@plasticmobile.com"))
 #        return Error(ECError["InvalidInput"], "'email' must end in @plasticmobile.com")
 #   end
    password = p['password']
    if password.nil?
         return Error(ECError["InvalidInput"], "'password' must not be nil")
   end

    token = ""


    url = 'http://picasaweb.google.com/data/entry/api/user/EMAIL?alt=json'
    url = url.gsub(/EMAIL/, email)
    uri = URI(url)
    resp = Net::HTTP.get(uri)

    if resp.include?("Unable to find")
        return Error(ECError["InvalidInput"], email + " is not a valid @plasticmobile.com user")
    end

    data = JSON.parse(resp)
    entry = data["entry"]
    name = entry["gphoto$nickname"]["$t"]
    if name.to_i != 0
        name = email.split("@")[0]
    end
    photo = entry["gphoto$thumbnail"]["$t"]

    # perform function
    collection = ECMongo.getCollection("Users")
    users = collection.find("email" => email).to_a
    user = {}
    if (users.length == 0)
        if (p["signup"].nil? || p["signup"] == false)
          return Error(ECError["UserNotFound"], email + " is not registered. Please register your account to login") 
        end 
        token = Utils.newID

        user["email"] = email
        user["password"] = Utils.encrypt(password)
        user["token"] = token
        user["name"] = name
        user["photo"] = photo
        collection.insert_one(user)
    else
        user = users[0]
        if (Utils.decrypt(user["password"]) != password)
            return Error(ECError["InvalidInput"], "'password' was incorrect")
        end
        user["name"] = name
        user["photo"] = photo
        collection.update_one({"_id" => user["_id"]},user)
        token = user["token"]
    end
    result['token'] = token
    result["user"] = safeObj(user)
    return formatResult(result)
end

get '/games' do
    ##Authentication
    authInfo = tokenAuthentication(request.env)
    if authInfo["success"] == false
        return formatResult(authInfo)
    end
    user = authInfo
    #Authentication

    result = defaultResult()
    
    collection = ECMongo.getCollection("Games")
    games = safeArray(collection.find().to_a)

    collection = ECMongo.getCollection("Predictions")
    predictions = safeArray(collection.find({"token" => user["token"]}).to_a)

    collection = ECMongo.getCollection("Teams")
    teams = collection.find().to_a
    teamsHash = {}
    
    for team in teams
        teamsHash[team["_id"]] = {"name" => team["name"], "image" => team["image"]}
    end

    predictionsHash = {}
    for prediction in predictions 
        predictionsHash[prediction["gameID"]] = prediction
    end

    gamePredictions = []
    for game in games 
        prediction = predictionsHash[game["gameID"]]
        game["hasBeenPredicted"] = true
        if prediction.nil?
            prediction = {}
            prediction["awayGoals"] = 0
            prediction["homeGoals"] = 0
            game["hasBeenPredicted"] = false
        end
        if prediction["points"].nil?
            prediction["points"] = 0
        end
        game["prediction"] = prediction
        game["cutOffTime"] = getCutOffTime(game["startTime"])
        game["awayTeam"] = teamsHash[game["awayTeam"]]
        game["homeTeam"] = teamsHash[game["homeTeam"]]
        gamePredictions.push(game)
    end

    result["data"] = gamePredictions
    return formatResult(result)
end


get '/teams' do
	result = defaultResult()
	collection = ECMongo.getCollection("Teams")
	teams = collection.find().to_a
	result["data"] = teams
	return formatResult(result)
end

get '/allgames' do
    result = defaultResult()
    collection = ECMongo.getCollection("Games")
    games = safeArray(collection.find().to_a)
	
        
    collection = ECMongo.getCollection("Teams")
    teams = collection.find().to_a
    teamsHash = {}
    
    for team in teams
        teamsHash[team["_id"]] = {"name" => team["name"], "image" => team["image"]}
    end

    gameList = []
    for game in games 
        game["homeTeam"] = teamsHash[game["homeTeam"]]
        game["awayTeam"] = teamsHash[game["awayTeam"]]
        gameList.push(game)
    end

    result["data"] = gameList
    return formatResult(result)
end

post '/predictgame' do
    ##Authentication
    authInfo = tokenAuthentication(request.env)
    if authInfo["success"] == false
        return formatResult(authInfo)
    end
    user = authInfo
    #Authentication
    
    result = defaultResult()

    #validate params
    p = {}
    if defined? params
        p = params
    end
    
    gameID = p["gameID"]
    if gameID.nil?
        return Error(ECError["InvalidInput"], "'gameID' must not be nil")
    end
    awayGoals = p["awayGoals"]
    if awayGoals.nil?
        return Error(ECError["InvalidInput"], "'awayGoals' must not be nil")
    end
    homeGoals = p["homeGoals"]
    if homeGoals.nil?
        return Error(ECError["InvalidInput"], "'homeGoals' must not be nil")
    end

    gamesCollection = ECMongo.getCollection("Games")
    game = gamesCollection.find({"_id" => gameID}).to_a

    if game.length == 0
    	return Error(ECError["InvalidInput"], "Game " + gameID + " does not exist")
    end
    game = game[0]

    currentTime = Time.now.to_i
    closedBetsTime = getCutOffTime(game["startTime"])

    if currentTime > closedBetsTime
    	return Error(ECError["NotAvailable"], "It is too late to predict this game")
    end

    collection = ECMongo.getCollection("Predictions")
    prediction = {}
    prediction["gameID"] = gameID
    prediction["awayGoals"] = awayGoals
    prediction["homeGoals"] = homeGoals
    prediction["token"] = user["token"]
    
    collection.delete_one({"gameID" => gameID, "token" => user["token"]})
    collection.insert_one(prediction)

    result["data"] = safeObj(prediction)
    return formatResult(result)
end    

get '/pool' do
    ##Authentication
    authInfo = tokenAuthentication(request.env)
    if authInfo["success"] == false
        return formatResult(authInfo)
    end
    #user = authInfo
    #Authentication

    result = defaultResult()

    usersCollection = ECMongo.getCollection("Users")
    users = usersCollection.find().to_a

    pointsCollection = ECMongo.getCollection("Points")
    points = pointsCollection.find().to_a
    pointsHash = {}
    for point in points
        pointsHash[point["_id"]] = point
    end

    pointList = []
    for user in users
        pointData = {}
        pointData["name"] = user["name"]
        pointData["photo"] = user["photo"]
        points = pointsHash[user["token"]]
        if points.nil?
            points = {"points" => 0}
        end
        pointData["points"] = points["points"]
        pointList.push(pointData)
    end

    sortedPointList = pointList.sort_by{|a| a["points"]}.reverse
    result["data"] = sortedPointList    
    #result["data"] = pointList
    return formatResult(result)
end

get '/predictions' do
	result = defaultResult()
	collection = ECMongo.getCollection('Predictions')
	predictions = collection.find().to_a
	result["data"] = predictions
	return formatResult(result)
end

def getCutOffTime(time)
	return time - (60 * 30)
end

def tokenAuthentication(requestInfo)
## token authentication
    token = requestInfo["TOKEN"]
    if token.nil?
        token = requestInfo["HTTP_TOKEN"]
    end

    if token.nil?
        return JSON.parse(Error(ECError["InvalidInput"], "'token' header required"))
    end

    collection = ECMongo.getCollection("Users")
    results = collection.find({"token" => token}).to_a

    if (results.length != 1)
        return JSON.parse(Error(ECError["UserNotFound"], "invalid token"))
    end
    
    user = results[0]
    ## token authentication
    return user
end

def safeArray(array)
    arr = []
    for obj in array
        obj.delete("_id")
        obj.delete("token")
        arr.push(obj)
    end 
    return arr
end

def safeObj(obj)
    obj.delete("_id")
    obj.delete("token")
    return obj
end


def defaultResult() 
    result = {}
    result["success"] = true
    result["errorCode"] = 0
    result["errorMessage"] = ""
    return result
end

def Error(code, message)
    result = {}
    result["success"] = false
    result["errorCode"] = code
    result["errorMessage"] = message
    return formatResult(result)
end

def formatResult(result)
    result.to_json()
end

ECError = {}
ECError["InvalidInput"] = 1
ECError["UserNotFound"] = 2
ECError["NotAvailable"] = 3


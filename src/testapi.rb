get '/test/setup' do

    teamA = {}
    teamA["name"] = "France"
    teamA["image"] = "http://104.131.118.14/images/France.png"
     
    teamB = {}
    teamB["name"] = "Ukraine"
    teamB["image"] = "http://104.131.118.14/images/Ukraine.png"
    
    teamC = {}
    teamC["name"] = "Spain"
    teamC["image"] = "http://104.131.118.14/images/Spain.png"
     
    game0 = {}
    game0["gameID"] = "0"
    game0["awayTeam"] = teamA
    game0["homeTeam"] = teamB
    game0["startTime"] = 1465617600
    game0["awayGoals"] = 0
    game0["homeGoals"] = 0

    game1 = {}
    game1["gameID"] = "1"
    game1["awayTeam"] = teamA
    game1["homeTeam"] = teamC
    game1["startTime"] = 1465531200
    game1["awayGoals"] = 0
    game1["homeGoals"] = 0

    game2 = {}
    game2["gameID"] = "2"
    game2["awayTeam"] = teamC
    game2["homeTeam"] = teamB
    game2["startTime"] = 1464840000
    game2["awayGoals"] = 3
    game2["homeGoals"] = 0

    collection = ECMongo.getCollection("Games")
    collection.drop
    collection.insert_many([game0, game1, game2])

    games = safeArray(collection.find().to_a)
    result = defaultResult()
    result["games"] = games
    return formatResult(result)
end


post '/test/login' do
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
    if (email.nil? || !email.include?("@plasticmobile.com"))
         return Error(ECError["InvalidInput"], "'email' must end in @plasticmobile.com")
    end
    password = p['password']
    if password.nil?
         return Error(ECError["InvalidInput"], "'password' must not be nil")
   end

    token = ""

    # perform function
    collection = ECMongo.getCollection("Users")
    users = collection.find("email" => email).to_a
    if (users.length == 0)
        if (p["signup"].nil? || p["signup"] == false)
          return Error(ECError["UserNotFound"], email + "is not registered. Please register your account to login") 
        end 
        user = {}
        token = Utils.newID

        user["email"] = email
        user["password"] = Utils.encrypt(password)
        user["token"] = token
        
        collection.insert_one(user)
    else
        user = users[0]
        if (Utils.decrypt(user["password"]) != password)
            return Error(ECError["InvalidInput"], "'password' was incorrect")
        end
        token = user["token"]
    end
    result['token'] = token

    return formatResult(result)
end

get '/test/pool' do
    ##Authentication
    authInfo = tokenAuthentication(request.env)
    if authInfo["success"] == false
        return formatResult(authInfo)
    end
    user = authInfo
    #Authentication

    result = defaultResult()
    brian = {}
    brian["name"] = "Brian"
    brian["points"] = 10

    oleksiy = {}
    oleksiy["name"] = "Oleksiy"
    oleksiy["points"] = 8

    omar = {}
    omar["name"] = "Omar"
    omar["points"] = 7

    sandeep = {}
    sandeep["name"] = "Sandeep"
    sandeep["points"] = 3

    result["data"] = [brian, oleksiy, omar, sandeep]

    return formatResult(result)
end

get '/test/games' do
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
    gamesHash = {}

    collection = ECMongo.getCollection("Predictions")
    predictions = safeArray(collection.find({"token" => user["token"]}).to_a)
    predictionsHash = {}
    for prediction in predictions 
        predictionsHash[prediction["gameID"]] = prediction
    end

    gamePredictions = []
    for game in games 
        prediction = predictionsHash[game["gameID"]]
        if prediction.nil?
            prediction = {}
            prediction["awayGoals"] = 0
            prediction["homeGoals"] = 0
        end
        game["prediction"] = prediction
        gamePredictions.push(game)
    end

    result["data"] = gamePredictions
    return formatResult(result)
end

post '/test/predictgame' do
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

    if gameID == "2"
        return Error(ECError["InvalidInput"], "it is too late to predict game 'gameID'")
    end
    if gameID != "0" && gameID != "1"
        return Error(ECError["InvalidInput"], "game 'gameID' does not exist")
    end

    collection = ECMongo.getCollection("Predictions")
    prediction = {}
    prediction["gameID"] = gameID
    prediction["awayGoals"] = awayGoals
    prediction["homeGoals"] = homeGoals
    prediction["token"] = user["token"]
    
    collection.delete_one({"gameID" => gameID, "token" => user["token"]}).to_a
    collection.insert_one(prediction)

    result["data"] = safeObj(prediction)
    return formatResult(result)
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
    

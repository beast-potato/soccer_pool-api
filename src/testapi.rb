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
    result = defaultResult()

    prediction0 = {}
    prediction0["awayGoals"] = 0
    prediction0["awayGoals"] = 0

    prediction1 = {}
    prediction1["awayGoals"] = 3
    prediction1["awayGoals"] = 0

    prediction2 = {}
    prediction2["awayGoals"] = 2
    prediction2["awayGoals"] = 1

    game0 = {}
    game0["gameID"] = "0"
    game0["awayTeam"] = "TEAM A"
    game0["homeTeam"] = "TEAM B"
    game0["startTime"] = "2016-06-11T18:00:00Z"
    game0["awayGoals"] = 0
    game0["homeGoals"] = 0
    game0["prediction"] = prediction0

    game1 = {}
    game1["gameID"] = "1"
    game1["awayTeam"] = "TEAM A"
    game1["homeTeam"] = "TEAM B"
    game1["startTime"] = "2016-06-10T18:00:00Z"
    game1["awayGoals"] = 0
    game1["homeGoals"] = 0
    game1["prediction"] = prediction1

    game2 = {}
    game2["gameID"] = "2"
    game2["awayTeam"] = "TEAM A"
    game2["homeTeam"] = "TEAM B"
    game2["startTime"] = "2016-06-02T18:00:00Z"
    game2["awayGoals"] = 3
    game2["homeGoals"] = 0
    game2["prediction"] = prediction2

    result["data"] = [game0, game1, game2]
    return formatResult(result)
end

post '/test/predictgame' do
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

    return formatResult(result)
end    


get '/' do
    result = defaultResult()
    result["data"] = "voy a destrozar tu cara"    
    return formatResult(result)   
end

post '/sample/login' do
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

    # perform function

    result["token"] = "t0k3n" + email + "t0k3n"

    return formatResult(result)
end

get '/sample/pool' do
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

get '/sample/games' do
    result = defaultResult()

    prediction0 = {}
    prediction0["awayGoals"] = 0
    prediction0["homeGoals"] = 0

    prediction1 = {}
    prediction1["awayGoals"] = 3
    prediction1["homeGoals"] = 0

    prediction2 = {}
    prediction2["awayGoals"] = 2
    prediction2["homeGoals"] = 1

    teamA = {}
    teamA["name"] = "Romania"
    teamA["flag"] = "https://upload.wikimedia.org/wikipedia/commons/7/73/Flag_of_Romania.svg"

    teamB = {}
    teamB["name"] = "France"
    teamB["flag"] = "https://upload.wikimedia.org/wikipedia/en/c/c3/Flag_of_France.svg"

    teamC = {}
    teamC["name"] = "Slovakia"
    teamC["flag"] = "https://upload.wikimedia.org/wikipedia/commons/e/e6/Flag_of_Slovakia.svg"



    game0 = {}
    game0["gameID"] = "0"
    game0["awayTeam"] = teamA
    game0["homeTeam"] = teamB
    game0["startTime"] = "2016-06-11T18:00:00Z"
    game0["awayGoals"] = 0
    game0["homeGoals"] = 0
    game0["prediction"] = prediction0

    game1 = {}
    game1["gameID"] = "1"
    game1["awayTeam"] = teamA
    game1["homeTeam"] = teamC
    game1["startTime"] = "2016-06-10T18:00:00Z"
    game1["awayGoals"] = 0
    game1["homeGoals"] = 0
    game1["prediction"] = prediction1

    game2 = {}
    game2["gameID"] = "2"
    game2["awayTeam"] = teamB
    game2["homeTeam"] = teamC
    game2["startTime"] = "2016-06-02T18:00:00Z"
    game2["awayGoals"] = 3
    game2["homeGoals"] = 0
    game2["prediction"] = prediction2

    result["data"] = [game0, game1, game2]
    return formatResult(result)
end

post '/sample/predictgame' do
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

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
        prediction["awayGoals"] = prediction["awayGoals"].to_i
        prediction["homeGoals"] = prediction["homeGoals"].to_i
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

    winner = nil
    if game["requiresWinner"]

        if awayGoals > homeGoals
            winner = "awayTeam"
        end

        if awayGoals < homeGoals
            winner = "homeTeam"
        end

        if winner.nil?
            return Error(ECError["InvalidInput"], "this game requires a winner")
        end
        if !(winner == "awayTeam" || winner == "homeTeam")
            return Error(ECError["InvalidInput"], "this game requires a winner")        
        end
    end
    
    currentTime = Time.now.to_i
    closedBetsTime = getCutOffTime(game["startTime"])

    if currentTime > closedBetsTime
    	return Error(ECError["NotAvailable"], "It is too late to predict this game")
    end

    collection = ECMongo.getCollection("Predictions")
    prediction = {}
    prediction["gameID"] = gameID
    prediction["awayGoals"] = awayGoals.to_i
    prediction["homeGoals"] = homeGoals.to_i
    prediction["token"] = user["token"]
    if !winner.nil?
        prediction["winner"] = winner
    end

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
        pointData["email"] = user["email"]
        pointData["name"] = user["name"]
        pointData["photo"] = user["photo"]
        points = pointsHash[user["token"]]
        if points.nil?
            points = {"points" => 0}
        end
        pointData["points"] = points["points"]
        pointList.push(pointData)
    end

    sortedPointList = pointList.sort_by{|a| [-a["points"], a["email"]]}
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


get '/brokengame' do
    return'{"success":true,"errorCode":0,"errorMessage":"","data":[{"gameID":"149855","awayTeam":{"name":"Romania","image":"http://104.131.118.14/images/Romania.png"},"homeTeam":{"name":"France","image":"http://104.131.118.14/images/France.png"},"state":"complete","startTime":1465585200,"requiresWinner":false,"awayGoals":1,"homeGoals":2,"winner":"homeTeam","hasBeenPredicted":true,"prediction":{"gameID":"149855","awayGoals":1,"homeGoals":2,"points":5,"winner":"homeTeam"},"cutOffTime":1465583400},{"gameID":"149885","awayTeam":{"name":"Switzerland","image":"http://104.131.118.14/images/Switzerland.png"},"homeTeam":{"name":"Albania","image":"http://104.131.118.14/images/Albania.png"},"state":"complete","startTime":1465650000,"requiresWinner":false,"awayGoals":1,"homeGoals":0,"winner":"awayTeam","hasBeenPredicted":true,"prediction":{"gameID":"149885","awayGoals":3,"homeGoals":0,"points":3,"winner":"awayTeam"},"cutOffTime":1465648200},{"gameID":"149861","awayTeam":{"name":"Slovakia","image":"http://104.131.118.14/images/Slovakia.png"},"homeTeam":{"name":"Wales","image":"http://104.131.118.14/images/Wales.png"},"state":"complete","startTime":1465660800,"requiresWinner":false,"awayGoals":1,"homeGoals":2,"winner":"homeTeam","hasBeenPredicted":true,"prediction":{"gameID":"149861","awayGoals":1,"homeGoals":2,"points":5,"winner":"homeTeam"},"cutOffTime":1465659000},{"gameID":"149860","awayTeam":{"name":"Russia","image":"http://104.131.118.14/images/Russia.png"},"homeTeam":{"name":"England","image":"http://104.131.118.14/images/England.png"},"state":"complete","startTime":1465671600,"requiresWinner":false,"awayGoals":1,"homeGoals":1,"winner":"tie","hasBeenPredicted":true,"prediction":{"gameID":"149860","awayGoals":1,"homeGoals":2,"points":1,"winner":"homeTeam"},"cutOffTime":1465669800},{"gameID":"149873","awayTeam":{"name":"Croatia","image":"http://104.131.118.14/images/Croatia.png"},"homeTeam":{"name":"Turkey","image":"http://104.131.118.14/images/Turkey.png"},"state":"complete","startTime":1465736400,"requiresWinner":false,"awayGoals":1,"homeGoals":0,"winner":"awayTeam","hasBeenPredicted":true,"prediction":{"gameID":"149873","awayGoals":2,"homeGoals":1,"points":2,"winner":"awayTeam"},"cutOffTime":1465734600},{"gameID":"149867","awayTeam":{"name":"Northern Ireland","image":"http://104.131.118.14/images/NorthernIreland.png"},"homeTeam":{"name":"Poland","image":"http://104.131.118.14/images/Poland.png"},"state":"complete","startTime":1465747200,"requiresWinner":false,"awayGoals":0,"homeGoals":1,"winner":"homeTeam","hasBeenPredicted":true,"prediction":{"gameID":"149867","awayGoals":1,"homeGoals":1,"points":1,"winner":"tie"},"cutOffTime":1465745400},{"gameID":"149866","awayTeam":{"name":"Ukraine","image":"http://104.131.118.14/images/Ukraine.png"},"homeTeam":{"name":"Germany","image":"http://104.131.118.14/images/Germany.png"},"state":"complete","startTime":1465758000,"requiresWinner":false,"awayGoals":0,"homeGoals":2,"winner":"homeTeam","hasBeenPredicted":true,"prediction":{"gameID":"149866","awayGoals":1,"homeGoals":3,"points":2,"winner":"homeTeam"},"cutOffTime":1465756200},{"gameID":"149872","awayTeam":{"name":"Czech Republic","image":"http://104.131.118.14/images/CzechRepublic.png"},"homeTeam":{"name":"Spain","image":"http://104.131.118.14/images/Spain.png"},"state":"complete","startTime":1465822800,"requiresWinner":false,"awayGoals":0,"homeGoals":1,"winner":"homeTeam","hasBeenPredicted":true,"prediction":{"gameID":"149872","awayGoals":0,"homeGoals":1,"points":5,"winner":"homeTeam"},"cutOffTime":1465821000},{"gameID":"149879","awayTeam":{"name":"Sweden","image":"http://104.131.118.14/images/Sweden.png"},"homeTeam":{"name":"Republic of Ireland","image":"http://104.131.118.14/images/RepublicofIreland.png"},"state":"complete","startTime":1465833600,"requiresWinner":false,"awayGoals":1,"homeGoals":1,"winner":"tie","hasBeenPredicted":true,"prediction":{"gameID":"149879","awayGoals":2,"homeGoals":1,"points":1,"winner":"awayTeam"},"cutOffTime":1465831800},{"gameID":"149878","awayTeam":{"name":"Italy","image":"http://104.131.118.14/images/Italy.png"},"homeTeam":{"name":"Belgium","image":"http://104.131.118.14/images/Belgium.png"},"state":"complete","startTime":1465844400,"requiresWinner":false,"awayGoals":2,"homeGoals":0,"winner":"awayTeam","hasBeenPredicted":true,"prediction":{"gameID":"149878","awayGoals":1,"homeGoals":1,"points":0,"winner":"tie"},"cutOffTime":1465842600},{"gameID":"149882","awayTeam":{"name":"Hungary","image":"http://104.131.118.14/images/Hungary.png"},"homeTeam":{"name":"Austria","image":"http://104.131.118.14/images/Austria.png"},"state":"complete","startTime":1465920000,"requiresWinner":false,"awayGoals":2,"homeGoals":0,"winner":"awayTeam","hasBeenPredicted":true,"prediction":{"gameID":"149882","awayGoals":0,"homeGoals":1,"points":0,"winner":"homeTeam"},"cutOffTime":1465918200},{"gameID":"149888","awayTeam":{"name":"Iceland","image":"http://104.131.118.14/images/Iceland.png"},"homeTeam":{"name":"Portugal","image":"http://104.131.118.14/images/Portugal.png"},"state":"complete","startTime":1465930800,"requiresWinner":false,"awayGoals":1,"homeGoals":1,"winner":"tie","hasBeenPredicted":true,"prediction":{"gameID":"149888","awayGoals":0,"homeGoals":2,"points":0,"winner":"homeTeam"},"cutOffTime":1465929000},{"gameID":"149859","awayTeam":{"name":"Slovakia","image":"http://104.131.118.14/images/Slovakia.png"},"homeTeam":{"name":"Russia","image":"http://104.131.118.14/images/Russia.png"},"state":"complete","startTime":1465995600,"requiresWinner":false,"awayGoals":2,"homeGoals":1,"winner":"awayTeam","hasBeenPredicted":true,"prediction":{"gameID":"149859","awayGoals":0,"homeGoals":1,"points":1,"winner":"homeTeam"},"cutOffTime":1465993800},{"gameID":"149854","awayTeam":{"name":"Switzerland","image":"http://104.131.118.14/images/Switzerland.png"},"homeTeam":{"name":"Romania","image":"http://104.131.118.14/images/Romania.png"},"state":"complete","startTime":1466006400,"requiresWinner":false,"awayGoals":1,"homeGoals":1,"winner":"tie","hasBeenPredicted":true,"prediction":{"gameID":"149854","awayGoals":1,"homeGoals":1,"points":5,"winner":"tie"},"cutOffTime":1466004600},{"gameID":"149884","awayTeam":{"name":"Albania","image":"http://104.131.118.14/images/Albania.png"},"homeTeam":{"name":"France","image":"http://104.131.118.14/images/France.png"},"state":"complete","startTime":1466017200,"requiresWinner":false,"awayGoals":0,"homeGoals":2,"winner":"homeTeam","hasBeenPredicted":true,"prediction":{"gameID":"149884","awayGoals":0,"homeGoals":2,"points":5,"winner":"homeTeam"},"cutOffTime":1466015400},{"gameID":"149858","awayTeam":{"name":"Wales","image":"http://104.131.118.14/images/Wales.png"},"homeTeam":{"name":"England","image":"http://104.131.118.14/images/England.png"},"state":"complete","startTime":1466082000,"requiresWinner":false,"awayGoals":1,"homeGoals":2,"winner":"homeTeam","hasBeenPredicted":true,"prediction":{"gameID":"149858","awayGoals":1,"homeGoals":0,"points":1,"winner":"awayTeam"},"cutOffTime":1466080200},{"gameID":"149865","awayTeam":{"name":"Northern Ireland","image":"http://104.131.118.14/images/NorthernIreland.png"},"homeTeam":{"name":"Ukraine","image":"http://104.131.118.14/images/Ukraine.png"},"state":"complete","startTime":1466092800,"requiresWinner":false,"awayGoals":2,"homeGoals":0,"winner":"awayTeam","hasBeenPredicted":true,"prediction":{"gameID":"149865","awayGoals":2,"homeGoals":1,"points":3,"winner":"awayTeam"},"cutOffTime":1466091000},{"gameID":"149864","awayTeam":{"name":"Poland","image":"http://104.131.118.14/images/Poland.png"},"homeTeam":{"name":"Germany","image":"http://104.131.118.14/images/Germany.png"},"state":"complete","startTime":1466103600,"requiresWinner":false,"awayGoals":0,"homeGoals":0,"winner":"tie","hasBeenPredicted":true,"prediction":{"gameID":"149864","awayGoals":0,"homeGoals":2,"points":1,"winner":"homeTeam"},"cutOffTime":1466101800},{"gameID":"149877","awayTeam":{"name":"Sweden","image":"http://104.131.118.14/images/Sweden.png"},"homeTeam":{"name":"Italy","image":"http://104.131.118.14/images/Italy.png"},"state":"complete","startTime":1466168400,"requiresWinner":false,"awayGoals":0,"homeGoals":1,"winner":"homeTeam","hasBeenPredicted":true,"prediction":{"gameID":"149877","awayGoals":0,"homeGoals":2,"points":3,"winner":"homeTeam"},"cutOffTime":1466166600},{"gameID":"149871","awayTeam":{"name":"Croatia","image":"http://104.131.118.14/images/Croatia.png"},"homeTeam":{"name":"Czech Republic","image":"http://104.131.118.14/images/CzechRepublic.png"},"state":"complete","startTime":1466179200,"requiresWinner":false,"awayGoals":2,"homeGoals":2,"winner":"tie","hasBeenPredicted":true,"prediction":{"gameID":"149871","awayGoals":2,"homeGoals":0,"points":1,"winner":"awayTeam"},"cutOffTime":1466177400},{"gameID":"149870","awayTeam":{"name":"Turkey","image":"http://104.131.118.14/images/Turkey.png"},"homeTeam":{"name":"Spain","image":"http://104.131.118.14/images/Spain.png"},"state":"complete","startTime":1466190000,"requiresWinner":false,"awayGoals":0,"homeGoals":3,"winner":"homeTeam","hasBeenPredicted":true,"prediction":{"gameID":"149870","awayGoals":0,"homeGoals":1,"points":3,"winner":"homeTeam"},"cutOffTime":1466188200},{"gameID":"149876","awayTeam":{"name":"Republic of Ireland","image":"http://104.131.118.14/images/RepublicofIreland.png"},"homeTeam":{"name":"Belgium","image":"http://104.131.118.14/images/Belgium.png"},"state":"complete","startTime":1466254800,"requiresWinner":false,"awayGoals":0,"homeGoals":3,"winner":"homeTeam","hasBeenPredicted":true,"prediction":{"gameID":"149876","awayGoals":0,"homeGoals":2,"points":3,"winner":"homeTeam"},"cutOffTime":1466253000},{"gameID":"149887","awayTeam":{"name":"Hungary","image":"http://104.131.118.14/images/Hungary.png"},"homeTeam":{"name":"Iceland","image":"http://104.131.118.14/images/Iceland.png"},"state":"complete","startTime":1466265600,"requiresWinner":false,"awayGoals":1,"homeGoals":1,"winner":"tie","hasBeenPredicted":true,"prediction":{"gameID":"149887","awayGoals":1,"homeGoals":2,"points":1,"winner":"homeTeam"},"cutOffTime":1466263800},{"gameID":"149881","awayTeam":{"name":"Austria","image":"http://104.131.118.14/images/Austria.png"},"homeTeam":{"name":"Portugal","image":"http://104.131.118.14/images/Portugal.png"},"state":"complete","startTime":1466276400,"requiresWinner":false,"awayGoals":0,"homeGoals":0,"winner":"tie","hasBeenPredicted":true,"prediction":{"gameID":"149881","awayGoals":1,"homeGoals":2,"points":0,"winner":"homeTeam"},"cutOffTime":1466274600},{"gameID":"149883","awayTeam":{"name":"Albania","image":"http://104.131.118.14/images/Albania.png"},"homeTeam":{"name":"Romania","image":"http://104.131.118.14/images/Romania.png"},"state":"complete","startTime":1466362800,"requiresWinner":false,"awayGoals":1,"homeGoals":0,"winner":"awayTeam","hasBeenPredicted":true,"prediction":{"gameID":"149883","awayGoals":0,"homeGoals":1,"points":0,"winner":"homeTeam"},"cutOffTime":1466361000},{"gameID":"149853","awayTeam":{"name":"France","image":"http://104.131.118.14/images/France.png"},"homeTeam":{"name":"Switzerland","image":"http://104.131.118.14/images/Switzerland.png"},"state":"complete","startTime":1466362800,"requiresWinner":false,"awayGoals":0,"homeGoals":0,"winner":"tie","hasBeenPredicted":true,"prediction":{"gameID":"149853","awayGoals":2,"homeGoals":1,"points":0,"winner":"awayTeam"},"cutOffTime":1466361000},{"gameID":"149857","awayTeam":{"name":"England","image":"http://104.131.118.14/images/England.png"},"homeTeam":{"name":"Slovakia","image":"http://104.131.118.14/images/Slovakia.png"},"state":"complete","startTime":1466449200,"requiresWinner":false,"awayGoals":0,"homeGoals":0,"winner":"tie","hasBeenPredicted":true,"prediction":{"gameID":"149857","awayGoals":1,"homeGoals":1,"points":2,"winner":"tie"},"cutOffTime":1466447400},{"gameID":"149856","awayTeam":{"name":"Wales","image":"http://104.131.118.14/images/Wales.png"},"homeTeam":{"name":"Russia","image":"http://104.131.118.14/images/Russia.png"},"state":"complete","startTime":1466449200,"requiresWinner":false,"awayGoals":3,"homeGoals":0,"winner":"awayTeam","hasBeenPredicted":true,"prediction":{"gameID":"149856","awayGoals":1,"homeGoals":0,"points":3,"winner":"awayTeam"},"cutOffTime":1466447400},{"gameID":"149863","awayTeam":{"name":"Poland","image":"http://104.131.118.14/images/Poland.png"},"homeTeam":{"name":"Ukraine","image":"http://104.131.118.14/images/Ukraine.png"},"state":"complete","startTime":1466524800,"requiresWinner":false,"awayGoals":1,"homeGoals":0,"winner":"awayTeam","hasBeenPredicted":true,"prediction":{"gameID":"149863","awayGoals":2,"homeGoals":0,"winner":"awayTeam","points":3},"cutOffTime":1466523000},{"gameID":"149862","awayTeam":{"name":"Germany","image":"http://104.131.118.14/images/Germany.png"},"homeTeam":{"name":"Northern Ireland","image":"http://104.131.118.14/images/NorthernIreland.png"},"state":"complete","startTime":1466524800,"requiresWinner":false,"awayGoals":1,"homeGoals":0,"winner":"awayTeam","hasBeenPredicted":true,"prediction":{"gameID":"149862","awayGoals":2,"homeGoals":1,"winner":"awayTeam","points":2},"cutOffTime":1466523000},{"gameID":"149869","awayTeam":{"name":"Turkey","image":"http://104.131.118.14/images/Turkey.png"},"homeTeam":{"name":"Czech Republic","image":"http://104.131.118.14/images/CzechRepublic.png"},"state":"complete","startTime":1466535600,"requiresWinner":false,"awayGoals":2,"homeGoals":0,"winner":"awayTeam","hasBeenPredicted":true,"prediction":{"gameID":"149869","awayGoals":1,"homeGoals":0,"winner":"awayTeam","points":3},"cutOffTime":1466533800},{"gameID":"149868","awayTeam":{"name":"Spain","image":"http://104.131.118.14/images/Spain.png"},"homeTeam":{"name":"Croatia","image":"http://104.131.118.14/images/Croatia.png"},"state":"complete","startTime":1466535600,"requiresWinner":false,"awayGoals":1,"homeGoals":2,"winner":"homeTeam","hasBeenPredicted":true,"prediction":{"gameID":"149868","awayGoals":1,"homeGoals":2,"winner":"homeTeam","points":5},"cutOffTime":1466533800},{"gameID":"149886","awayTeam":{"name":"Austria","image":"http://104.131.118.14/images/Austria.png"},"homeTeam":{"name":"Iceland","image":"http://104.131.118.14/images/Iceland.png"},"state":"complete","startTime":1466611200,"requiresWinner":false,"awayGoals":1,"homeGoals":2,"winner":"homeTeam","hasBeenPredicted":true,"prediction":{"gameID":"149886","awayGoals":1,"homeGoals":2,"winner":"homeTeam","points":5},"cutOffTime":1466609400},{"gameID":"149880","awayTeam":{"name":"Portugal","image":"http://104.131.118.14/images/Portugal.png"},"homeTeam":{"name":"Hungary","image":"http://104.131.118.14/images/Hungary.png"},"state":"complete","startTime":1466611200,"requiresWinner":false,"awayGoals":3,"homeGoals":3,"winner":"tie","hasBeenPredicted":true,"prediction":{"gameID":"149880","awayGoals":1,"homeGoals":0,"winner":"awayTeam","points":0},"cutOffTime":1466609400},{"gameID":"149875","awayTeam":{"name":"Belgium","image":"http://104.131.118.14/images/Belgium.png"},"homeTeam":{"name":"Sweden","image":"http://104.131.118.14/images/Sweden.png"},"state":"complete","startTime":1466622000,"requiresWinner":false,"awayGoals":1,"homeGoals":0,"winner":"awayTeam","hasBeenPredicted":true,"prediction":{"gameID":"149875","awayGoals":2,"homeGoals":0,"winner":"awayTeam","points":3},"cutOffTime":1466620200},{"gameID":"149874","awayTeam":{"name":"Republic of Ireland","image":"http://104.131.118.14/images/RepublicofIreland.png"},"homeTeam":{"name":"Italy","image":"http://104.131.118.14/images/Italy.png"},"state":"complete","startTime":1466622000,"requiresWinner":false,"awayGoals":1,"homeGoals":0,"winner":"awayTeam","hasBeenPredicted":true,"prediction":{"gameID":"149874","awayGoals":0,"homeGoals":2,"winner":"homeTeam","points":0},"cutOffTime":1466620200},{"gameID":"150457","awayTeam":{"name":"Poland","image":"http://104.131.118.14/images/Poland.png"},"homeTeam":{"name":"Switzerland","image":"http://104.131.118.14/images/Switzerland.png"},"state":"upcoming","startTime":1466859600,"requiresWinner":true,"awayGoals":0,"homeGoals":0,"winner":"tie","hasBeenPredicted":true,"prediction":{"gameID":"150457","awayGoals":1,"homeGoals":0,"winner":"awayTeam","points":0},"cutOffTime":1466857800},{"gameID":"150458","awayTeam":{"name":"Spain","image":"http://104.131.118.14/images/Spain.png"},"homeTeam":{"name":"Italy","image":"http://104.131.118.14/images/Italy.png"},"state":"upcoming","startTime":1467043200,"requiresWinner":true,"awayGoals":0,"homeGoals":0,"winner":"tie","hasBeenPredicted":false,"prediction":{"awayGoals":0,"homeGoals":0,"points":0},"cutOffTime":1467041400},{"gameID":"150463","awayTeam":{"name":"Northern Ireland","image":"http://104.131.118.14/images/NorthernIreland.png"},"homeTeam":{"name":"Wales","image":"http://104.131.118.14/images/Wales.png"},"state":"upcoming","startTime":1466870400,"requiresWinner":true,"awayGoals":0,"homeGoals":0,"winner":"tie","hasBeenPredicted":false,"prediction":{"awayGoals":0,"homeGoals":0,"points":0},"cutOffTime":1466868600},{"gameID":"150462","awayTeam":{"name":"Portugal","image":"http://104.131.118.14/images/Portugal.png"},"homeTeam":{"name":"Croatia","image":"http://104.131.118.14/images/Croatia.png"},"state":"upcoming","startTime":1466881200,"requiresWinner":true,"awayGoals":0,"homeGoals":0,"winner":"tie","hasBeenPredicted":false,"prediction":{"awayGoals":0,"homeGoals":0,"points":0},"cutOffTime":1466879400},{"gameID":"150461","awayTeam":{"name":"Republic of Ireland","image":"http://104.131.118.14/images/RepublicofIreland.png"},"homeTeam":{"name":"France","image":"http://104.131.118.14/images/France.png"},"state":"upcoming","startTime":1466946000,"requiresWinner":true,"awayGoals":0,"homeGoals":0,"winner":"tie","hasBeenPredicted":false,"prediction":{"awayGoals":0,"homeGoals":0,"points":0},"cutOffTime":1466944200},{"gameID":"150460","awayTeam":{"name":"Slovakia","image":"http://104.131.118.14/images/Slovakia.png"},"homeTeam":{"name":"Germany","image":"http://104.131.118.14/images/Germany.png"},"state":"upcoming","startTime":1466956800,"requiresWinner":true,"awayGoals":0,"homeGoals":0,"winner":"tie","hasBeenPredicted":false,"prediction":{"awayGoals":0,"homeGoals":0,"points":0},"cutOffTime":1466955000},{"gameID":"150459","awayTeam":{"name":"Belgium","image":"http://104.131.118.14/images/Belgium.png"},"homeTeam":{"name":"Hungary","image":"http://104.131.118.14/images/Hungary.png"},"state":"upcoming","startTime":1466967600,"requiresWinner":true,"awayGoals":0,"homeGoals":0,"winner":"tie","hasBeenPredicted":false,"prediction":{"awayGoals":0,"homeGoals":0,"points":0},"cutOffTime":1466965800},{"gameID":"150464","awayTeam":null,"homeTeam":{"name":"England","image":"http://104.131.118.14/images/England.png"},"state":"upcoming","startTime":1467054000,"requiresWinner":true,"awayGoals":0,"homeGoals":0,"winner":"tie","hasBeenPredicted":false,"prediction":{"awayGoals":0,"homeGoals":0,"points":0},"cutOffTime":1467052200}]}'
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


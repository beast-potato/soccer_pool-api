
get '/' do
    result = defaultResult()
    result["data"] = "voy a destrozar tu cara"    
    return formatResult(result)   
end

post '/sample/login' do
    result = defaultResult()
    result["token"] = ""    

    email = params["email"]
    password = params["password"]

    if email == nil 
         result["errorCode"] = ECError["InvalidInput"]
        result["errorMessage"] = "email must end in @plasticmobile.com"
        return formatResult(result)
    end 
    if password == nil
        result["errorCode"] = ECError["InvalidInput"]
        result["errorMessage"] = "password cannot be nil"
        return formatResult(result)
    end
    if !email.include? "@plasticmobile.com"
        result["errorCode"] = ECError["InvalidInput"]
        result["errorMessage"] = "email must end in @plasticmobile.com"
        return formatResult(result)
    end
    result["token"] = email

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

def defaultResult() 
    result = {}
    result["success"] = true
    result["errorCode"] = 0
    result["errorMessage"] = ""
    return result
end

def formatResult(result)
    result.to_json()
end

ECError = {}
ECError["InvalidInput"] = 1 

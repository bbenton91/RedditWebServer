import asynchttpserver, asyncdispatch, nim-templates-master/templates, RedditApi/Reddit, json

var server = newAsyncHttpServer()

proc testPage (name: string, results: seq[JsonNode]): string = tmplf "test.html"

# echo testPage("Charlie")

proc cb(req: Request) {.async.} =
    if req.url.path == "/get-saved" and req.reqMethod == HttpMethod.HttpPost:
        echo "got a post"
        echo req.body

        let code = parseJson(req.body)["code"].getStr()

        # var reddit = newReddit("y_LmR31bMjlTBQ", "Cnzt0PoMNEh2YztgC_JvQVg5En7oBA", "Pahaz", "Suchasandorwith12")
        # Connect using web auth
        var user = Reddit.connectAuth("C6iDiQaoPTwgVw","m9Ze8qmjzHO7yuU9KyE3lCKoJQzdYQ", code, "http://localhost:3000")
        # If the user is valid, try to get the saved posts. Otherwise, return default data
        let (saved, newUser) = if user.kind == ValidUser:
                                    user.getSaved(fields = @["title"])
                                else:
                                    (newSeq[JsonNode](), user)

        echo saved.len

        let headers = newHttpHeaders()
        headers["Access-Control-Allow-Headers"] = "Content-Type,access-control-allow-origin"
        headers["Access-Control-Allow-Origin"] = "*"
        headers["Access-Control-Allow-Methods"] = "POST,GET"
        headers["Content-Type"] = "application/json"

        # This is our data to return to the server. For the token, we use the newUser.token if its a valid user. Otherwise just empty string
        let returnData = {"data": $saved, "token": if newUser.kind == ValidUser: newUser.token else: ""}

        await req.respond(Http200, $saved, headers)

    elif req.url.path == "/list" and req.reqMethod == HttpMethod.HttpPost:
        var user = connectPassword("y_LmR31bMjlTBQ", "Cnzt0PoMNEh2YztgC_JvQVg5En7oBA", "Pahaz", "Suchasandorwith12")
        var (data, newUser) = user.getSaved(fields = @["title"])
        
        echo "listing"
        await req.respond(Http200, testPage("Paha", data))
    elif req.url.path == "/":
        echo "normal path"
        await req.respond(Http200, "Hello")
    else:
        echo "Some other path here"
        # echo req.url.path
        # echo req.reqMethod
        # echo req.headers

        var headers = newHttpHeaders()
        headers["Access-Control-Allow-Headers"] = "Content-Type,access-control-allow-origin"
        headers["Access-Control-Allow-Origin"] = "*"
        headers["Access-Control-Allow-Methods"] = "POST,GET"
        await req.respond(Http200, "", headers)

waitFor server.serve(Port(7070), cb)
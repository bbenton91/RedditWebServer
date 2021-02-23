import asynchttpserver, asyncdispatch, nim-templates-master/templates, json, tables
import RedditApi/src/Reddit, Session

let session = newSession()
var server = newAsyncHttpServer()

proc testPage (name: string, results: seq[JsonNode]): string = tmplf "test.html"

# echo testPage("Charlie")

proc headers():HttpHeaders = 
    newHttpHeaders({
        "Access-Control-Allow-Headers": "Content-Type,access-control-allow-origin",
        "Access-Control-Allow-Origin":"*",
        "Access-Control-Allow-Methods": "POST,GET",
        "Content-Type":"application/json"
    })

proc getChunkedContent(user:User, isNew:bool, after:string): Future[(JsonNode, seq[JsonNode], User)] {.async.} =
    ## Gets partial saved content. `user` is the User to pull content from, `isNew` is to signal if this is a brand-new request,
    ## and `after` is a string which is the last 'after' object from a reddit api request.
    
    # If 'after' is empty, then we can assume we don't need to fetch anymore
    if after == "":
        result = (newJObject(), newSeq[JsonNode](), user)
    else:
        let urlParams = newUrlParams({"after": after}.toTable());

        let (rawJson, savedLinks, userAfterLinks) = if user.kind == ValidUser:
                                    await user.getSaved(fields = @["title", "url", "permalink", "id", "is_self", "subreddit", "author"], extraParams=urlParams)
                                else:
                                    (newJObject(), newSeq[JsonNode](), user)

proc fetchAndReturnSavedListings(req:Request, user:User, webToken:string, newSessionId:string, oldSessionId:string) {.async.} =
    # If the user is valid, try to get the saved posts. Otherwise, return default data
    let (_, savedLinks, userAfterLinks) = if user.kind == ValidUser:
                                await user.getAllSaved(fields = @["title", "url", "permalink", "id", "is_self", "subreddit", "author"])
                            else:
                                (newSeq[JsonNode](), user)

    let (savedComments, refreshedUser) = if userAfterLinks.kind == ValidUser:
                                await userAfterLinks.getAllSaved(fields = @["title", "url", "permalink", "id", "is_self", "subreddit", "author", "body"], listingType = Comment)
                            else:
                                (newSeq[JsonNode](), userAfterLinks)

    let headers = headers()

    # This is our data to return to the server. For the token, we use the newUser.token if its a valid user. Otherwise just empty string
    let returnData = %* {"savedLinks": savedLinks,
                        "savedComments": savedComments, 
                        "sessionId": if refreshedUser.kind == ValidUser: newSessionId else: ""}

    await req.respond(Http200, $ returnData, headers)

    session.setUserSession(newSessionId, oldSessionId, "", "", newUserSession(refreshedUser))


proc unsaveListing(req:Request, user:User, webToken:string, newSessionId:string, oldSessionId:string) {.async.} =
    let postData = parseJson(req.body)
    let fullname = postData["fullname"].getStr("")

    let (sucess, newUser) = if user.kind == ValidUser:
                                await user.unsave(fullname)
                            else:
                                (false, user)
    
    let headers = headers()

    # This is our data to return to the server. For the token, we use the newUser.token if its a valid user. Otherwise just empty string
    let returnData = %* {"success": sucess, 
                        "sessionId": if newUser.kind == ValidUser: newSessionId else: ""}

    await req.respond(Http200, $ returnData, headers)

    session.setUserSession(newSessionId, oldSessionId, "", "", newUserSession(newUser))


proc cb(req: Request) {.async, gcsafe.} =
    if req.reqMethod == HttpMethod.HttpPost:
        echo "got a post"
        # echo req.body
        # echo req.headers

        # Get the post data
        let postData = parseJson(req.body)
        let webToken:string = if postData.hasKey("token"): postData["token"].getStr else: ""
        let sessionId = postData["sessionId"].getStr("")

        # Grab our session
        var (userSession, newSessionId) = session.getUserSession(sessionId, "")

         # Then we can either make a new user or grab one for the session
        var user:User
        if userSession == nil or userSession.user.kind == InvalidUser: # If the session is nil or our user is invalid, we need a new user
            echo "session is nil or user kind is invalid. Nil? " & $(userSession == nil)
            # Connect using web auth
            user = await Reddit.connectAuth("C6iDiQaoPTwgVw","m9Ze8qmjzHO7yuU9KyE3lCKoJQzdYQ", webToken, "http://localhost:3000")
        else: # Otherwise we got one right here
            user = userSession.user
            if user.tokens.isExpired():
                user = newInvalidUser("Session expired")

        if req.url.path == "/get-saved":
            await fetchAndReturnSavedListings(req, user, webToken, newSessionId, sessionId)
        elif req.url.path == "/unsave":
            await unsaveListing(req, user, webToken, newSessionId, sessionId)

    elif req.url.path == "/list" and req.reqMethod == HttpMethod.HttpPost:
        # var user = connectPassword("aI-ujHrrKdOsZg", "dNw2jGHX65ejS8JxkMDkKZtNKk8", "Pahaz", "Suchasandorwith12")

        var user = connectPassword("y_LmR31bMjlTBQ", "Cnzt0PoMNEh2YztgC_JvQVg5En7oBA", "Pahaz", "Suchasandorwith12")
        var (data, newUser) = await user.getSaved(fields = @["title"])
        
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
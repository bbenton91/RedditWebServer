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

proc getChunkedContent*(user:User, isNew:bool, after:string, listingType:ListingType): Future[(string, seq[JsonNode], User)] {.async.} =
    ## Gets partial saved content. `user` is the User to pull content from, `isNew` is to signal if this is a brand-new request,
    ## and `after` is a string which is the last 'after' object from a reddit api request.
    
    # If 'after' is empty, then we can assume we don't need to fetch anymore
    if after == "" and not isNew:
        result = ("", newSeq[JsonNode](), user)

    # Otherwise we try to fetch the next batch
    else:
        # The params for 'after'
        let urlParams = newUrlParams({"after": after}.toTable());

        # Get the data
        let data = if user.kind == ValidUser:
                                    await user.getSaved(fields = @["title", "url", "permalink", "id", "is_self", "subreddit", "author", "body"], extraParams=urlParams, listingType=listingType)
                                else:
                                    newErrorResult(user)
        
        # We get the next 'after' string to return. If it exists, we return it. Otherwise, return an empty string
        let nextAfter = if data.data.hasKey("data") and data.data["data"].hasKey("after"): data.data["data"]["after"].getStr() else: ""
        result = (nextAfter, data.resultData, data.updatedUser)

proc fetchAndReturnSavedListingsChunked(req:Request, userSession:UserSession, listingType:ListingType, isNew:bool, oldSessionId:string, newSessionId:string) {.async.} =
    let after = if isNew: "" else: userSession.nextAfter # get the 'after' string

    echo "after is " & after

    # Then fetch the data
    let (nextAfter, content, refreshedUser) = await getChunkedContent(userSession.user, isNew, after, listingType)

    # Then prepare to send back
    let headers = headers()

    echo nextAfter

    var returnData:JsonNode

    if listingType == Link:
        # This is our data to return to the server. For the token, we use the newUser.token if its a valid user. Otherwise just empty string
        returnData = %* {"savedLinks": content,
                            "sessionId": if refreshedUser.kind == ValidUser: newSessionId else: "",
                            "finished": nextAfter == ""}
    else:
        returnData = %* {"savedComments": content,
                            "sessionId": if refreshedUser.kind == ValidUser: newSessionId else: "",
                            "finished": nextAfter == ""}
    
    # Set the user session
    session.setUserSession(newSessionId, oldSessionId, "", "", newUserSession(refreshedUser, nextAfter))

    # send
    await req.respond(Http200, $ returnData, headers)
    

proc fetchAndReturnSavedListings(req:Request, user:User, webToken:string, newSessionId:string, oldSessionId:string) {.async.} =
    # If the user is valid, try to get the saved posts. Otherwise, return default data
    let linkData = if user.kind == ValidUser:
                                await user.getAllSaved(fields = @["title", "url", "permalink", "id", "is_self", "subreddit", "author"])
                            else:
                                newErrorResult(user)

    let commentData = if linkData.updatedUser.kind == ValidUser:
                                await linkData.updatedUser.getAllSaved(fields = @["title", "url", "permalink", "id", "is_self", "subreddit", "author", "body"], listingType = Comment)
                            else:
                                newErrorResult(linkData.updatedUser)

    let headers = headers()

    # This is our data to return to the server. For the token, we use the newUser.token if its a valid user. Otherwise just empty string
    let returnData = %* {"savedLinks": linkData.resultData,
                        "savedComments": commentData.resultData, 
                        "sessionId": if commentData.updatedUser.kind == ValidUser: newSessionId else: ""}

    await req.respond(Http200, $ returnData, headers)

    session.setUserSession(newSessionId, oldSessionId, "", "", newUserSession(commentData.updatedUser))


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

proc getAndValidateUserSession(oldSessionId:string, webToken:string): Future[(UserSession, string)] {.async.} =
    ## Attempts to get a valid user from the session. If not able, an Invalid user is returned. A new session ID is also returned
    ## for access to the session.

    var (userSession, newSessionId) = session.getUserSession(oldSessionId, "")

    if userSession == nil or userSession.user.kind == InvalidUser: # If the session is nil or our user is invalid, we need a new user
        echo "session is nil or user kind is invalid. Nil? " & $(userSession == nil)
        # Connect using web auth
        var user = await Reddit.connectAuth("C6iDiQaoPTwgVw","m9Ze8qmjzHO7yuU9KyE3lCKoJQzdYQ", webToken, "http://localhost:3000")
        var userSession = newUserSession(user, "")
        session.setUserSession(newSessionId, oldSessionId, "", "", newUserSession(user))
        result = (userSession, newSessionId)
    else: # Otherwise we got one right here
        var user = userSession.user
        if user.tokens.isExpired():
            user = newInvalidUser("Session expired")
        var userSession = newUserSession(user, userSession.nextAfter)
        session.setUserSession(newSessionId, oldSessionId, "", "", newUserSession(user))
        result = (userSession, newSessionId)

proc cb(req: Request) {.async, gcsafe.} =
    if req.reqMethod == HttpMethod.HttpPost:
        echo "got a post"
        # echo req.body
        # echo req.headers

        # Get the post data
        let postData = parseJson(req.body)
        let webToken:string = if postData.hasKey("token"): postData["token"].getStr else: ""
        let sessionId = postData["sessionId"].getStr("")
        let isNew:bool = if postData.hasKey("isNew"): postData["isNew"].getBool else: false
        let contentType = if postData.hasKey("listingType"): postData["listingType"].getStr else: "Comment"
        let listingType = if contentType == "link": ListingType.Link else: ListingType.Comment

        # Grab our session

         # Then we can either make a new user or grab one for the session
        let (userSession, newSessionId) = await getAndValidateUserSession(sessionId, webToken)
        
        if req.url.path == "/get-saved":
            await fetchAndReturnSavedListingsChunked(req, userSession, listingType, isNew, sessionId, newSessionId)
            # await fetchAndReturnSavedListings(req, userSession.user, webToken, newSessionId, sessionId)
        elif req.url.path == "/unsave":
            await unsaveListing(req, userSession.user, webToken, newSessionId, sessionId)

    elif req.url.path == "/list" and req.reqMethod == HttpMethod.HttpPost:
        # var user = connectPassword("aI-ujHrrKdOsZg", "dNw2jGHX65ejS8JxkMDkKZtNKk8", "Pahaz", "Suchasandorwith12")

        var user = connectPassword("y_LmR31bMjlTBQ", "Cnzt0PoMNEh2YztgC_JvQVg5En7oBA", "Pahaz", "Suchasandorwith12")
        var data = await user.getSaved(fields = @["title"])
        
        echo "listing"
        await req.respond(Http200, testPage("Paha", data.resultData))
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

# var queueTable:Table[string, UserQueue]

waitFor server.serve(Port(7070), cb)
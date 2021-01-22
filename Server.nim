import asynchttpserver, asyncdispatch, nim-templates-master/templates, json, tables
import RedditApi/Reddit, Session

let session = newSession()
var server = newAsyncHttpServer()

proc testPage (name: string, results: seq[JsonNode]): string = tmplf "test.html"

# echo testPage("Charlie")

proc cb(req: Request) {.async, gcsafe.} =
    if req.url.path == "/get-saved" and req.reqMethod == HttpMethod.HttpPost:
        echo "got a post"
        # echo req.body
        # echo req.headers

        # Get the post data
        let postData = parseJson(req.body)
        let webToken = postData["token"].getStr("")
        let sessionId = postData["sessionId"].getStr("")

        # Grab our session
        var (userSession, newSessionId) = session.getUserSession(sessionId, "")

        # Then we can either make a new user or grab one for the session
        var user:User
        if userSession == nil or userSession.user.kind == InvalidUser: # If the session is nil or our user is invalid, we need a new user
            echo "session is nil or user kind is invalid. Nil? " & $(userSession == nil)
            # Connect using web auth
            user = Reddit.connectAuth("C6iDiQaoPTwgVw","m9Ze8qmjzHO7yuU9KyE3lCKoJQzdYQ", webToken, "http://localhost:3000")
        else: # Otherwise we got one right here
            user = userSession.user

        # If the user is valid, try to get the saved posts. Otherwise, return default data
        let (saved, newUser) = if user.kind == ValidUser:
                                    user.getSaved(fields = @["title"])
                                else:
                                    (newSeq[JsonNode](), user)

        # Then we save back into the session. Note here that newUser could be an InvalidUser. The next request for the session will
        # have to authenticate with reddit again
        session.setUserSession(newSessionId, sessionId, "", "", newUserSession(newUser))

        let headers = newHttpHeaders()
        headers["Access-Control-Allow-Headers"] = "Content-Type,access-control-allow-origin"
        headers["Access-Control-Allow-Origin"] = "*"
        headers["Access-Control-Allow-Methods"] = "POST,GET"
        headers["Content-Type"] = "application/json"

        echo "Sending new session id " & newSessionId

        # This is our data to return to the server. For the token, we use the newUser.token if its a valid user. Otherwise just empty string
        let returnData = %* {"data": saved, 
                            "sessionId": if newUser.kind == ValidUser: newSessionId else: ""}

        await req.respond(Http200, $ returnData, headers)

    elif req.url.path == "/list" and req.reqMethod == HttpMethod.HttpPost:
        # var user = connectPassword("aI-ujHrrKdOsZg", "dNw2jGHX65ejS8JxkMDkKZtNKk8", "Pahaz", "Suchasandorwith12")

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
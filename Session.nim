import tables, RedditApi/src/Reddit, random

type 
    UserSession* = ref object
        user*: User
        nextAfter*: string

    Session = ref object
        sessionTable: TableRef[string, UserSession]

proc newSession*():Session =
    Session(sessionTable: newTable[string, UserSession]())

proc newUserSession*(user:User, nextAfter:string = ""):UserSession =
    UserSession(user:user, nextAfter:nextAfter)

method getNewSessionId(this:Session, length:int):string {.base.} =
    # @ through Z is 64-90
    # a through z is 96-122
    # We need to essentially add anything higher than 90 by 6 to exclude the symbols

    randomize()
    var id:string = ""
    var counter = 0
    while counter < length:
        var num = rand(64..(122-6)) # We subtract the higher end by 6 because we add 6 below to raise it up. This is to exclude a section of ascii symbols
        num = if num > 90: num + 6 else: num
        id &= $char(num) # Convert the ascii number to a character. Then $ converts to string
        counter += 1
    id

method validateSession(this:Session) {.base.} =
    discard

method getUserSession*(this:Session, sessionId:string, sessionKey:string):(UserSession, string) {.base.} =
    # TODO need to validate here before getting
    #validate
    ( this.sessionTable.getOrDefault(sessionId, nil), this.getNewSessionId(24) )

method setUserSession*(this:Session, sessionId:string, oldSessionId:string, newSessionKey:string, oldSessionKey:string, userSession: UserSession) {.base.} =
    this.sessionTable[sessionId] = userSession
    this.sessionTable.del(oldSessionId)
    # TODO probably should validate here before setting


import ../RedditApi/src/Reddit
# import ../Server.nim
import asyncdispatch, json, tables

let user = connectPassword("y_LmR31bMjlTBQ", "Cnzt0PoMNEh2YztgC_JvQVg5En7oBA", "Pahaz", "Suchasandorwith12")
var resultData = waitFor user.getSaved() 
var acc = newSeq[JsonNode]()

var count = 0

while resultData.data["data"]["after"].getStr() != "":
    resultData = waitFor user.getSaved(extraParams=newUrlParams({"after": resultData.data["data"]["after"].getStr}.toTable()))
    echo resultData.data["data"]["after"].getStr()
    acc = acc & resultData.resultData
    count += 1
    if count > 2:
        break

doAssert acc.len > 100 or count > 1

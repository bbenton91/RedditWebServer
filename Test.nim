import asyncdispatch, httpclient

proc asyncProc(): Future[string] {.async.} =
  var client = newAsyncHttpClient()
  return await client.postContent("http://localhost:7070/get-saved")
#   return await client.getContent("http://example.com")

echo waitFor asyncProc()
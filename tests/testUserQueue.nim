import ../UserQueue, sugar, options, asyncdispatch
import ../RedditApi/src/Reddit

proc test() =
    let testProc = proc():Future[ResultObj] {.closure, gcsafe, async.} = result = newErrorResult(newInvalidUser("Testing"), "just testing")

    let userQueue = newQueueTable()

    # ! This is a temp solution until I learn to work in nim...
    # Can't easily pass closures I guess
    var value:ResultObj
    let action = newAction(proc():Future[void] {.async, gcsafe.} = value = await testProc())

    var user = userQueue["Tom"]
    doAssert user.isNone

    userQueue.addNewUser("Tom")
    user = userQueue["Tom"]

    doAssert user.isSome

    user.get.pushAction(action)

    doAssert user.get.hasNextAction()

    let popped = user.get.popNextAction()
    if popped.isSome():
        waitFor popped.get.fun()
        doAssert value.kind == ErrorResult

    let emptyPop = user.get.popNextAction()
    doAssert emptyPop.isNone

    doAssert userQueue.contains("Tom")
    doAssert not userQueue.contains("Betty")

test()
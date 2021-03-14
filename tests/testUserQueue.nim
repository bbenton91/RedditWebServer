import ../UserQueue, sugar, options
import ../RedditApi/src/Reddit

let testProc = proc():ResultObj {.closure.} = newErrorResult(newInvalidUser("Testing"), "just testing")

let userQueue = newQueueTable()

# ! This is a temp solution until I learn to work in nim...
# Can't easily pass closures I guess
var value:ResultObj
let action = newAction(proc() = value = testProc())
userQueue.pushAction("Tom", action)

let popped = userQueue.popNextAction("Tom")
if popped.isSome():
    popped.get.fun()
    assert value.kind == ErrorResult

let emptyPop = userQueue.popNextAction("Tom")
assert emptyPop.isNone

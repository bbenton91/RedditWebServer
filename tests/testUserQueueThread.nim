import options, asyncdispatch
# from ../ThreadHandler import receiver, chan
import ../UserQueue
import ../Message

var chan*: Channel[ChannelMessage]

proc receiver*() {.thread.} =
    echo "hey"

proc test() =
    # var channel = newSharedChannel[Message]()
    # channel.open()

    chan.open()

    var queueTable = newQueueTable()

    # let testProc = proc():Future[void] {.closure, async, gcsafe.} = discard newErrorResult(newInvalidUser("Testing"), "just testing")
    let testProc = proc(): Future[void] {.closure, async, gcsafe.} = echo "Hey there"

    let userQueue = newQueueTable()

    # Make the action
    let action = newAction(proc():Future[void] {.async, gcsafe.} = discard testProc())

    # var worker1: Thread[SharedChannel[Message]]

    # Start the thread with the queueTable
    var worker1: Thread[void]
    createThread(worker1, receiver)

    let message:ChannelMessage = newChannelMessage(action, "Tom")
    chan.send(message)
    # let msg = Message(userName:"Tom", action: testProc)

    # Add a new user and push the action for the thread to handle
    queueTable.addNewUser("Tom")
    queueTable["Tom"].get.pushAction(action)
    queueTable["Tom"].get.pushAction(action)
    queueTable["Tom"].get.pushAction(action)
    queueTable["Tom"].get.pushAction(action)
    # channel.send(msg)

    worker1.joinThread()

test()
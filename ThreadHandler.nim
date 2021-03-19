import asyncdispatch, options
import UserQueue, SharedChannel

type
    Message* = ref object
        action*:proc():Future[void]{.async, gcsafe.}
        userName*: string

# var chan*: Channel[Message]

proc processAction*(fun:proc(){.async, gcsafe.}, userQueue:UserQueue):Future[void] {.async, gcsafe.} =
    userQueue.isProcessing = true
    await fun()
    userQueue.isProcessing = false

proc receiver*(queueTable: UserTable) {.thread.} =
    echo "Receiver is starting"
    # let queueTable = newQueueTable()
    while true:
        # let data = tryRecv(channel[])

        # If we had a message, let's process it
        # if data.dataAvailable:
        #     echo "Got msg"
        #     var userQueueOption = queueTable[data.msg.userName]

        #     # If we don't have a userQueue, make an entry first
        #     if userQueueOption.isNone:
        #         queueTable.addNewUser(data.msg.userName)
        #         userQueueOption = queueTable[data.msg.userName] # Reassign
           
        #     let userQueue = userQueueOption.get

        #     # If the queue is busy or has something in line
        #     if userQueue.isProcessing or userQueue.hasNextAction:
        #         userQueue.pushAction newAction(data.msg.action)
        #     # Otherwise we can just do it immediately
        #     else:
        #         waitFor processAction(data.msg.action, userQueue)

        # # If no message, lets keep working on the queue if possible
        # else:
        for queue in queueTable.values: 
            # If the queue is not busy but has something left to process
            if not queue.isProcessing and queue.hasNextAction():
                let action = queue.popNextAction()
                if action.isSome:
                    waitFor processAction(action.get.fun, queue)
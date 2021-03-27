import asyncdispatch, options, os
import UserQueue
import Message

# type
#     Message* = ref object
#         action*:proc():Future[void]{.async, gcsafe.}
#         username*: string

var chan*: Channel[ChannelMessage]

proc processAction*(fun:proc(){.async, gcsafe.}, userQueue:UserQueue):Future[void] {.async, gcsafe.} =
    userQueue.isProcessing = true
    await fun()
    userQueue.isProcessing = false

proc receiver*() {.thread.} =
    echo "Receiver is starting"
    let queueTable = newQueueTable()
    while true:
        let data = chan.tryRecv()
        if data.dataAvailable:
            echo "Got it"

        # If we had a message, let's process it
        if data.dataAvailable:
            echo "Got msg"
            var userQueueOption = queueTable[data.msg.username]

            # If we don't have a userQueue, make an entry first
            if userQueueOption.isNone:
                queueTable.addNewUser(data.msg.username)
                userQueueOption = queueTable[data.msg.username] # Reassign
           
            let userQueue = userQueueOption.get

            # If the queue is busy or has something in line
            if userQueue.isProcessing or userQueue.hasNextAction:
                # userQueue.pushAction newAction(data.msg.action)
                discard
            # Otherwise we can just do it immediately
            else:
                discard
                # waitFor processAction(data.msg.action, userQueue)

        # If no message, lets keep working on the queue if possible
        else:
            for queue in queueTable.values: 
                # If the queue is not busy but has something left to process
                if not queue.isProcessing and queue.hasNextAction():
                    let action = queue.popNextAction()
                    if action.isSome:
                        discard
                        # asyncCheck processAction(action.get.fun, queue)
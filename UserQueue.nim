import tables, sugar, options, heapqueue
import ../RedditApi/src/Reddit

type
    Action = ref object
        fun*: proc()

    UserQueue* = ref object
        isProcessing: bool
        queue: HeapQueue[Action]
        # table: TableRef[string, HeapQueue[Action]]

proc newAction*(fun: proc()): Action =
    Action(fun: fun)

proc newQueueTable*():TableRef[string, UserQueue] =
    let table = newTable[string, UserQueue]()
    table

proc newUserQueue(): UserQueue =
    UserQueue(queue: initHeapQueue[Action](), isProcessing: false)

method popNextAction*(this: TableRef[string, UserQueue], name:string): Option[Action] {.base.} =
    if this.contains(name) and this[name].queue.len > 0:
        let val = some(this[name].queue.pop())
        if this[name].queue.len == 0: # make sure to clean up empty queues
            this.del(name)
        return val

    return none(Action)

method pushAction*(this:TableRef[string, UserQueue], name:string, action:Action) {.base.} =
    if this.contains(name):
        this[name].queue.push(action)
    else:
        this[name] = newUserQueue()
        this[name].queue.push(action)

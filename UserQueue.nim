import tables, sugar, options, heapqueue, asyncdispatch

type
    Action* = ref object
        fun*: proc():Future[void] {.async, gcsafe.}

    UserTable* = ref object
        table: TableRef[string, UserQueue]

    UserQueue* = ref object
        isProcessing*: bool
        queue: HeapQueue[Action]
        # table: TableRef[string, HeapQueue[Action]]

proc newAction*(fun: proc():Future[void] {.async, gcsafe.}): Action =
    Action(fun: fun)

proc newQueueTable*(): UserTable =
    UserTable(table: newTable[string, UserQueue]())

proc newUserQueue(): UserQueue =
    UserQueue(queue: initHeapQueue[Action](), isProcessing: false)

proc `[]`*(this: UserTable, name:string): Option[UserQueue] =
    if this.table.contains(name):
        return some(this.table[name])
    none(UserQueue)

proc `[]`*(this: ref UserTable, name:string): Option[UserQueue] =
    if this.table.contains(name):
        return some(this.table[][name])
    none(UserQueue)

proc `[]=`*(this: UserTable, name:string, value:UserQueue) =
    this.table[name] = value

method contains*(this:UserTable, name:string):bool {.base.} = 
    this.table.contains(name)

iterator values*(this:UserTable): UserQueue =
    for item in this.table.values:
        yield item

iterator keys*(this:UserTable): string =
    for item in this.table.keys:
        yield item

method addNewUser*(this:UserTable, name:string) {.base.} =
    this.table[name] = newUserQueue()

method popNextAction*(this: UserQueue): Option[Action] {.base.} =
    if this.queue.len > 0:
        let val = some(this.queue.pop())
        # if this.queue.len == 0: # make sure to clean up empty queues
        #     this.table.del(name)
        return val
    return none(Action)

method pushAction*(this:UserQueue, action:Action) {.base.} =
    this.queue.push(action)
    
method hasNextAction*(this:UserQueue):bool {.base.} =
    this.queue.len > 0
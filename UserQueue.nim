import tables, sugar, options, heapqueue
import ../RedditApi/src/Reddit

type
    Action = ref object
        fun*: proc()

    UserQueue = ref object
        table: TableRef[string, HeapQueue[Action]]

proc newAction*(fun: proc()): Action =
    Action(fun: fun)

proc newUserQueue*(): UserQueue =
    let table = newTable[string, HeapQueue[Action]]()
    UserQueue(table: table)

method popNextAction*(this: UserQueue, name:string): Option[Action] {.base.} =
    if this.table.contains(name) and this.table[name].len > 0:
        let val = some(this.table[name].pop())
        if this.table[name].len == 0: # make sure to clean up empty queues
            this.table.del(name)
        return val

    return none(Action)

method pushAction*(this:UserQueue, name:string, action:Action) {.base.} =
    if this.table.contains(name):
        this.table[name].push(action)
    else:
        this.table[name] = initHeapQueue[Action]()
        this.table[name].push(action)

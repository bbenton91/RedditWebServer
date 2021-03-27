import asyncdispatch, os, sugar
import UserQueue

type
    ChannelMessage* = object
        # Faction:proc():Future[void]{.async, gcsafe.}
        Faction: Action
        username*: string

proc newChannelMessage*(action: Action, username: string): ChannelMessage =
    ChannelMessage(Faction: action, username: username)

method action(this: ChannelMessage): Action {.base.} =
    this.Faction
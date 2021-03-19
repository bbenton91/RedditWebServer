import os

## `SharedChannel`, a wrapper to `Channel` that can be shared between threads.
## Documentation removed from source. See `Channel` documentation for the corresponding procs.
type
  SharedChannel*[TMsg] = ptr Channel[TMsg]

func `$`*[TMsg](c: SharedChannel[TMsg]): string =
  result = $c[]

func repr*[TMsg](c: SharedChannel[TMsg]): string =
  result = repr(c[])

proc newSharedChannel*[TMsg]: SharedChannel[TMsg] =
  result = cast[SharedChannel[TMsg]](allocShared0(sizeof(Channel[TMsg])))

proc open*[TMsg](c: var SharedChannel[TMsg]; maxItems: int = 0) =
  open(c[], maxItems)

proc trySend*[TMsg](c: var SharedChannel[TMsg]; msg: TMsg): bool =
  result = trySend(c[], msg)

proc send*[TMsg](c: var SharedChannel[TMsg]; msg: TMsg) =
  send(c[], msg)

proc tryRecv*[TMsg](c: var SharedChannel[TMsg]): tuple[dataAvailable: bool, msg: TMsg] =
  result = tryRecv(c[])

proc peek*[TMsg](c: var SharedChannel[TMsg]): int =
  result = peek(c[])

proc recv*[TMsg](c: var SharedChannel[TMsg]): TMsg =
  result = recv(c[])

proc close*[TMsg](c: var SharedChannel[TMsg]) =
  close(c[])
  deallocShared(c)
  c = nil

proc ready*[TMsg](c: var SharedChannel[TMsg]): bool =
  result = ready(c[])
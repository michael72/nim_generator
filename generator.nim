import macros, options
when defined(js):
  error("JS backend is not supported (threads:on)")

import threadpool, locks

type
  Generator*[U, T] = ref object
    gen*: U
    next_call: GeneratorNext[U, T]
    finish_call: GeneratorFinish[U, T]
  GeneratorNext[U, T] = proc(g: var Generator[U, T]): Option[T] {.nimcall.}
  GeneratorFinish[U, T] = proc(g: var Generator[U, T]) {.nimcall.}

proc generatorFinishNoAction(g: var Generator) {.nimcall.} =
  discard

proc initGenerator*[U, T](genInit: U,
       next: GeneratorNext[U, T],
       finish: GeneratorFinish[U, T] = generatorFinishNoAction): auto =
  result = Generator[U, T](gen: genInit, next_call: next, finish_call: finish)

proc next*[U, T](g: var Generator[U, T]): Option[T] =
  g.next_call(g) # call the actual callback

proc finish*(g: var Generator) =
  g.finish_call(g)

iterator items*[U, T](g: var Generator[U, T]): T =
  ## Iterator implementation for the receiving part of all data from the `Generator`.
  while true:
    let n = g.next()
    if n.isSome:
      yield n.get()
    else:
      g.finish()
      break

type
  GenParamSync* = ref object
    ## Helper type for genparam to synchronize sending / receiving of data between threads.
    lock*: Lock
    sendCond*: Cond
    recvCond*: Cond

proc initGenParamSync*(): GenParamSync =
  result = GenParamSync(lock: Lock(), sendCond: Cond(), recvCond: Cond())
  initLock(result.lock)

type
  GeneratorThread*[T] = Thread[GenParamProvider[T]]
  GenParamProvider*[T] = proc(): GenParam[T] {.gcsafe.}
  GenParam*[T] = ref object
    ## Generic param to send data `T` between threads
    sync: GenParamSync
    res: Option[T]
    thr: Option[GeneratorThread[T]]
  GenIter*[T] = Generator[GenParam[T], T]

proc initGenParam[T](): auto =
  result = GenParam[T](sync: initGenParamSync(), res: none(T),
                       thr: none(GeneratorThread[T]))

proc send*[T](g: GenParam, it: T) =
  ## Sets the result to the receiver, wakes it up and waits until the receiver is done getting the data.
  withLock g.sync.lock:
    g.res = some(it)
    g.sync.recvCond.signal()
    g.sync.sendCond.wait(g.sync.lock)

proc stop*(g: GenParam) =
  ## Only wakes up the receiver that gets a none-option and terminates.
  ## This should be called when no more data is available to send.
  withLock g.sync.lock:
    g.sync.recvCond.signal()

proc rcv[T](g: GenParam[T]): Option[T] =
  ## Internally gets the received data and resets it to none (no data received).
  result = g.res
  g.res = none(T)

proc createGenerator*[T](genParam: GenParam[T],
                         thr: GeneratorThread[T]): GenIter[T] =
  ## Creates a receiver for the data from the given `GenParam` and in turn
  ## provides the data as a `Generator`.
  genParam.thr = some(thr)
  result = initGenerator(genParam,
    (proc (g: var GenIter[T]): Option[T] =
    # `next` implementation: receive the next item
    var l = g.gen.sync
    withLock l.lock:
      l.sendCond.signal()
      l.recvCond.wait(l.lock)
      result = g.gen.rcv()
  ), proc(g: var GenIter[T]) =
    # `finish` implementation: join threads
    if g.gen.thr.isSome():
      joinThread(g.gen.thr.get())
      g.gen.thr = none(GeneratorThread[T])
  )

proc createGeneratorThread*[T](
    feeder: proc(gp: GenParamProvider[T]) {.thread.}): GenIter[T] =
  var
    thr {.global.}: Thread[GenParamProvider[int]]
    genParam {.global.} = initGenParam[int]()

  proc genParamProviderImpl(): GenParam[int] =
    {.gcsafe.}:
      result = genParam

  createThread[GenParamProvider[int]](thr, feeder, genParamProviderImpl)
  result = createGenerator(genParam, thr)

proc wrapIterator(iterName: NimNode, iterType: NimNode): NimNode =
  # Generate a proc that is the counterpart to the `Generator.items` implementation.
  result = quote:
    block:
      proc sender(gp: GenParamProvider[`iterType`]) {.thread.} =
        var g = gp()
        for i in `iterName`():
          g.send(i)
        g.stop()

      createGeneratorThread(sender)

macro mkGeneratorTyped(iter: untyped, td: typedesc): untyped =
  ## Interim-macro to get the type of the underlying iterator
  ## which is essentially the generic `T` type.
  result = wrapIterator(iter, td.getType[1])

macro generator*(iter: untyped): untyped =
  ## Generates code and creates a wrapper for a given iterator.
  ## The wrapper can be passed around freely.
  ##
  ## As an example,
  ##
  ## .. code-block:: nim
  ## iterator foo(): int =
  ##   var i = -1
  ##   while i < 20:
  ##     i += 2
  ##     yield i
  ##     i += 3
  ##     yield i
  ## var bar = mkGenerator(foo)
  ##
  ## will create a variable `bar` of type `Generator` which - again - can be iterated -
  ## or it can be used to generate 1 or n items when calling the next function.
  ## Using a mutable `var` here is necessary as the generator changes the internal state
  ## when iterated on. So
  ##
  ## ..code-block:: nim
  ## echo([bar.next().get(), bar.next().get(), bar.next().get()])
  ## for i in bar:
  ##   echo $i & " "
  ##
  ## will print ```[1, 4, 6]``` and ```9 11 14 16 19 21 24```.
  ## The iterator only iterates on the _remaining_ items when `next` has been called before.
  result = quote:
    mkGeneratorTyped(`iter`, type(`iter`()))


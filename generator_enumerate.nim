import generator, options

type Enumerator*[T] = tuple[idx: int, elem: T]
type EnumGenInput[U, T] = Enumerator[Generator[U, T]]
type EnumeratorGenerator*[U, T] = Generator[EnumGenInput[U, T], Enumerator[T]]
proc initEnumerator*[T](idx: int, elem: T): Enumerator[T] =
  result = (idx: idx, elem: elem)

proc enumerate*[U, T](gen: var Generator[U, T]): EnumeratorGenerator[U, T] =
  ## Enumerates the given generator. The return type is determined by the input type `Generator[U,T]`
  ## wrapped with Enumerator: `Enumerator[Generator[U,T]]` is the "new U" = `EnumGenInput` for the generator,
  ## meaning: take the previous enumerator and add the info needed for the new enumerator Enumerator[T]
  ## which is the output type, resulting in the complex expression of
  ## `Generator[Enumerator[Generator[U, T]], Enumerator[T]]` which is `EnumeratorGenerator[U,T]`
  let init: EnumGenInput[U, T] = (idx: 0, elem: gen)
  initGenerator(init, proc(g: var EnumeratorGenerator[U, T]): Option[Enumerator[T]] =
    let next_elem = g.gen.elem.next()
    if next_elem.isSome():
      result = some(initEnumerator(g.gen.idx, next_elem.get()))
      g.gen.idx += 1
    else:
      result = none(Enumerator[T]))

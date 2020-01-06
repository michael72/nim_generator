import unittest, generator, generator_enumerate, options, sequtils

suite "generator tests":

  test "creating a raw generator":
    var gen_doubles = initGenerator(0,
      proc(g: var Generator[int, float64]): auto =
      g.gen += 1
      if g.gen < 10:
        return some(2.1 * float64(g.gen))
      return none(float64))

    check(gen_doubles.next().get() == 2.1)
    check(gen_doubles.next().get() == 4.2)

  test "wrapping an inline iterator":
    proc fun(): GenIter[int] =
      iterator foo(): int =
        var i = -1
        while i < 20:
          i += 2
          yield i
          i += 3
          yield i
      result = generator(foo)
    proc getSeq(): seq[int] =
      var bar = fun()
      result = bar.toSeq()

    check(getSeq() == @[1, 4, 6, 9, 11, 14, 16, 19, 21, 24])

  test "next removes elements from the iterator":
    iterator i123(): int =
      yield 1
      yield 2
      yield 3

    var gen = generator(i123)

    check(gen.next() == some(1))
    check(gen.toSeq() == @[2, 3])

  test "enumerator on generator":
    var gen_strings = initGenerator(0,
      proc(g: var Generator[int, string]): Option[string] =
      if g.gen < 3:
        g.gen += 1
        return some(["one", "two", "three"][g.gen-1])
      return none(string))
    var en = enumerate(gen_strings)
    check(en.toSeq() == @[(0, "one"), (1, "two"), (2, "three")])

import unittest, generator, options, sequtils

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
      result = mkGenerator(foo)
    proc getSeq(): seq[int] =
      var bar = fun()
      result = bar.toSeq()

    check(getSeq() == @[1, 4, 6, 9, 11, 14, 16, 19, 21, 24])

  test "next removes elements from the iterator":
    iterator i123(): int =
      yield 1
      yield 2
      yield 3

    var gen = mkGenerator(i123)

    check(gen.next() == some(1))
    check(gen.toSeq() == @[2, 3])



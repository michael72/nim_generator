# nim_generator
Generator wrapper for iterators in nim

[![Build Status](https://travis-ci.org/michael72/nim_generator.svg?branch=master)](https://travis-ci.org/michael72/nim_generator)

## Abstract 
Iterators in nim are not easy to handle. Passing the iterator around is not possible with inline-iterators and has some restrictions when using closures. Once started iterators have to run until the end. Try writing a `zip` function that combines two iterators - it is merely impossible (given that both iterators run undeterminedly).
It is not possible to pause execution and continue - as it is possible in Python. Python also supports getting the next element with a `next` function. 
The generator tries to copy exactly that behavior in Python and wraps the iterator with a `Generator` type that supports a `next` and a `finish` function and also provides its own items-iterator implementation so that it can also be used as an iterator again after passing it around.

The implementation (currently) uses threads - one `GeneratorThread` for each generator - that feeds the data from the iterator to the main thread where the data can be received item by item.

This is still in early stage - although the general concept is already working.
Help is welcome ;-)

## TODOs
* performance test
* more documentation
* zip -> generate tuples (or adapt zero_functional to support that - e.g. iterate until one of the iterators has ended).
* enumerate (as in python = zip with index)
* test with file reading iterator
* forward exceptions (?)

module main

import math.big
import rand

struct Fibonacci {
mut:
	cache []big.Integer = [big.zero_int, big.one_int]
}

pub fn (mut fib Fibonacci) prepare(estimate int) ! {
	if estimate < 0 {
		return error('estimate must be positive')
	}
	for i in fib.cache.len .. estimate + 1 {
		fib.cache << fib.nth(i - 2)! + fib.nth(i - 1)!
	}
}

pub fn (mut fib Fibonacci) nth(n int) !big.Integer {
	if n < 0 {
		return error('n must be positive')
	}

	// Base cases
	if n == 0 {
		return big.zero_int
	}
	if n == 1 {
		return big.one_int
	}

	if n < fib.cache.len {
		return fib.cache[n]
	}

	for i in fib.cache.len .. n + 1 {
		fib.cache << fib.nth(i - 2)! + fib.nth(i - 1)!
	}

	return fib.cache[n]
}

fn main() {
	count := 30

	mut fib := Fibonacci{}

	fib.prepare(200)!

	for _ in 0 .. count {
		n := rand.int_in_range(100, 300)!
		println('${n:4d}: ${fib.nth(n)!}')
	}

	// We cannot call prepare here
	// fib.prepare(200)!
}

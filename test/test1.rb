#!/usr/bin/env ruby

DeclTest = 1
GLOBCONST=1
$GLOBVAR=1

class Test1
	GV = 1
	def initialize
		@t = 1
		@s = "DD"
	end
	def hello
		l1 = 4 + @t + 4
		f1 = 2.1
		l2 = GLOBCONST
		puts "Hello"
		l2 = rand
	end
	def Test1.m1
	end
end

module TM1
	A=1
end

ttt = Test1.new
ttt.hello
nilv = nil
truev = true
falsev = false

cc = 1 + DeclTest

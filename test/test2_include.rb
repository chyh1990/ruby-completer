class Object
end

module Fixnum
	def to_s
	end
end

module Kernel
	def warn
	end
end
include Kernel

class Test1
	include Fixnum
	def hello
	end
end



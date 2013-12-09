##% Method<^args,ret>
class Method
  ##% "=="<t> : t -> Boolean
  def ==(p0) end
  ##% "[]" : (^args) -> ret
  def [](*rest) end
  ##% arity : () -> Fixnum
  def arity() end
  ##% call : (^args) -> ret
  def call(*) end
  ##% clone<self> : () -> self
  def clone(*) end
  ##% inspect : () -> String
  def inspect() end
  ##% to_proc : () -> Proc<^args,ret>
  def to_proc() end
  ##% to_s : () -> String
  def to_s() end
  ##% unbind : () -> UnboundMethod<^args,ret>
  def unbind() end
end



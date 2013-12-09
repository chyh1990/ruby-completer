#!/usr/bin/env ruby

require 'ruby_parser'
require 'sexp_processor'
require 'pp'

#p RubyParser.new.parse "1+1"
fail unless ARGV[0]

class Var < Struct.new(:name, :type, :scope); end
class Func < Var; end
class Scope < Struct.new(:type, :childs, :parent, :name, :varlist, :info); end

class KlassNode < Struct.new(:name, :superklass, :scope)
	def to_s
		return "#{name}##{superklass || "nil"}"
	end
	def inspect
		to_s
	end
end
class ModuleNode < Struct.new(:name, :scope); end

RootKlassNode = KlassNode.new(:Object, nil)

class FuncType < Struct.new(:ret, :args)
	def self.parse(str)
		t1 = str.split ':'
		return nil if t1[1].nil?
		t2 = t1[1].split '->'
		return FuncType.new(t2.last.strip.to_sym, [])
	end
	def inspect
		return "(#{@args.join(",") rescue nil}) -> #{ret.inspect}"
	end
end

$UNITID = 0
class TypeExtractor
	def initialize(src, base_type_unit = [])
		#type, childs, parent, name, varlist
		@scope = Scope.new :module, {}, nil, "___GLBOAL__", {}, nil
		@curscope = @scope
		@src = src.split(/\r?\n/)
		@base_type_unit = base_type_unit
		@block_idx = 0
		@unit_id = $UNITID
		$UNITID += 1
		#merge
		@scope.childs = {}
		@base_type_unit.each {|b|
			#XXX reopen class
			@scope.childs.merge! b.scope.childs
			@scope.varlist.merge! b.scope.varlist
		}	
	end

	def scope
		@scope
	end

	def get_block_name
		@block_idx+=1
		"___BLOCK_#{@unit_id}_#{@block_idx}".to_sym
	end
	def find_parent_scope(type)
		s = @curscope
		loop do
			break unless s
			return s if s.type == type
			s = s.parent
			break unless s
		end
		nil
	end
	def find_scope_with_name(type, name)
		#XXX
		s = @curscope
		loop do
			break unless s
			return s if s.type == type && s.name == name
			if s.childs
				t = s.childs[name]
				return t if t && t.type == type
			end
			s = s.parent
			break unless s
		end
		nil
	end
	def find_var_by_name(name, scope = @curscope)
		s = scope
		loop do
			break unless s
			t = s.varlist[name]
			return t if t
			s = s.parent
		end
		nil
	end

	def toplevel
		@scope.childs[:___BLOCK_0]
	end
	def find_top_level_by_name(name)
		return nil unless name
		return toplevel.childs[name]
	end
	def find_method_in_class(klassScope, name)
		fail "Not class" unless klassScope.type == :class
		klassNode = klassScope.info
		loop do
			return nil unless klassNode && klassNode.scope
			s = klassNode.scope
			#p "#{klassNode.name} #{s.varlist.keys}"
			f = s.varlist[name]
			#p "#{f.type} #{f.name}" if f
			#p f.class if f
			return f if f && Func === f
			#superklass = klassScope.info
			klassNode = klassNode.superklass
		end
	end

	def find_method_in_module(scope, name)
		s = scope
		loop do
			break unless s
			if s.type == :module
				t = s.varlist[name]
				return t if t && Func === t
			end
			s = s.parent
		end
		nil
	end

	def _extractRHSType(rhs)
		#TODO
		case rhs[0]
		when :lit
			return :Fixnum
		when :str
			return :String
		when :nil
			return :NilClass
			#XXX
		when :true, :false
			return :Boolean
		when :const
			t = find_var_by_name(rhs[1])
			return nil unless t
			case t
			when Var
				return t.type
			when KlassNode
				return t.name
			when ModuleNode
				return t.name
			else
				fail "TODO #{t.class}"
			end
			# expr 
		when :call
			#XXX deal with module call
			m = nil
			if rhs[1].nil?
				sc = find_parent_scope :class
				if sc
					m = find_method_in_class(sc, rhs[2])
					m ||= find_method_in_module(@curscope, rhs[2])
				else
					m = find_method_in_module(@curscope, rhs[2])
				end
			else
				recv_type = _extractRHSType(rhs[1])
				return nil if recv_type.nil?
				sc = find_scope_with_name :class, recv_type
				return recv_type if rhs[2] == :new && !rhs[1].nil?
				m = find_method_in_class(sc, rhs[2])
			end

			return nil unless m
			#p m.name
			#XXX deal with override and self type
			rettype = m.type.first.ret
			rettype = recv_type if rettype == :self
			return rettype
			#p "XXX #{m.inspect} #{rhs[2].inspect}"
			#nil
		else
			nil
		end
	end
	def extractRHSType(rhs)
		_extractRHSType rhs
	end

	def extractFuncType(def_node)
		#from annotation
		lines = []
		(def_node.line - 2).downto(0) do |i|
			t = @src[i].strip
			return lines unless t.start_with? '##%'
			lines << FuncType.parse(t[3..-1].strip)
		end
	end

	def doNode(ast)
		return unless ast
		newscope = false
		fail "XX #{ast.line}" unless @curscope
		case ast[0]
		when :block, :class, :module, :defn
			#p ast[0]
			@curscope.childs = Hash.new if @curscope.childs.nil?
			unless Symbol === ast[1]
				sn = get_block_name
			else
				sn = ast[1]
			end
			#XXX reopen class
			#nn = @curscope.childs[sn] || Scope.new(ast[0], {}, @curscope, 
		#		       sn, {})
			nn = Scope.new(ast[0], {}, @curscope, 
				       sn, {})
			@curscope.childs[sn] = nn
			@curscope = nn
			newscope = true
			if ast[0] == :defn
				#puts @src[ast.line-1]
				@curscope.parent.varlist[ast[1]] = Func.new(ast[1], extractFuncType(ast), @curscope.parent)
			elsif ast[0] == :class
				if ast[1] == :Object
					RootKlassNode.scope = @curscope
					@curscope.info = RootKlassNode
				else
					superklass_name = case ast[2]
							  when nil
								  :Object
							  when Symbol
								  ast[2]
							  when Sexp
								  case ast[2][0]
								  when :const
									  ast[2][1]
								  else
									  fail "no support @ #{ast.line} #{ast}"
								  end
							  end
					superscope = find_scope_with_name :class, superklass_name
					fail "no superklass #{ast[1]} #{superklass_name} @ #{ast.line}, #{ast.inspect}" unless superscope
					klassNode = KlassNode.new ast[1], superscope.info, @curscope
					@curscope.info = klassNode
				end
				@curscope.parent.varlist[ast[1]] = @curscope.info
				#@curscope.info = 
			elsif ast[0] == :module
				@curscope.parent.varlist[ast[1]] = ModuleNode.new(ast[1], @curscope)
			end
		when :iasgn, :lasgn
			#TODO
			if ast[1].to_s.start_with? '@'
				s = find_parent_scope :class
			else
				s = @curscope
			end
			s.varlist[ast[1]] = Var.new(ast[1], extractRHSType(ast[2]), @curscope)
		when :cdecl #define const
			@curscope.varlist[ast[1]] = Var.new(ast[1], extractRHSType(ast[2]), @curscope)
		when :gasgn
			@scope.varlist[ast[1]] = Var.new(ast[1], extractRHSType(ast[2]), @curscope)
		when :call
			if ast[1].nil? && ast[2] == :include
				#s = find_parent_scope(:class) || find_parent_scope(:module)
				#insert all methods and vars
				included_s = find_scope_with_name :module, _extractRHSType(ast[3])
				#XXX deep copy?
				#p included_s.varlist.keys
				if included_s
					@curscope.varlist.merge! included_s.varlist
					@curscope.childs.merge! included_s.childs
				end
			end
		end
		ast.each {|n| 
			next unless Sexp === n
			doNode n
		}
		fail "NN #{ast.line}" unless @curscope.parent if newscope
		@curscope = @curscope.parent if newscope
	end

	def doCompilationUnit(ast)
		#fail "no global block" unless ast[0] == :block
		if ast[0] == :block
			ast[1..-1].each {|n|
				doNode(n)
			}
		else
			doNode(ast)
		end
	end

	def inspect
		@scope.inspect
	end

	def _printme(n, ident)
		puts "#{' ' * ident}#{n.name}(#{n.type rescue "*"}, #{n.info}): #{n.varlist.map{|k,v| "#{k.inspect}:#{(v.type rescue "*").inspect}"}.join(', ') }"
		n.childs.each{|k,v| _printme(v, ident+2)} if n.childs
	end
	def printme()
		_printme(@scope, 0)
	end

	def add_global(name, type)
		ng = Var.new(name.to_sym, type.to_sym, @scope)
		@scope.varlist[name] = ng
	end
end

def load_base
	puts "Loading base..."
	extras = {
		'$`' => "prematch",
		'$\'' => "postmatch",
		'$+' => "highestmatch",
		'$&' => "last-match", # string last matched
		'$0' => "progname", # name of ruby script file
		'$:' => ["libraries"],
		'$"' => ["loaded-files"],
		'$1' => "matched" ,
		'$2' => "matched" ,
		'$3' => "matched" ,
		'$4' => "matched" ,
		'$5' => "matched" ,
		'$6' => "matched" ,
		'$7' => "matched" ,
		'$8' => "matched" ,
		'$9' => "matched" ,
	}

	c = File.read("./base_types.rb")
	#c = File.read("./bt1.rb")
	ast = RubyParser.new.parse c
	t = TypeExtractor.new c
	t.doCompilationUnit(ast)
	extras.each {|k,v| t.add_global k, v.class.name}
	return t
end

BASE_TYPE = load_base

c = File.read(ARGV[0])
ast = RubyParser.new.parse c
p ast

#processor = MyProcessor.new
#p processor.process(ast)
t = TypeExtractor.new c, [BASE_TYPE]
t.doCompilationUnit(ast)
#pp t

t.printme


#!/usr/bin/env ruby

require 'ruby_parser'
require 'sexp_processor'
require 'pp'
fail "no input" unless ARGV[0]

ast = Ruby18Parser.new.parse File.read(ARGV[0]), "(string)", 100
pp ast


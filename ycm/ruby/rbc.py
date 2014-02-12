from ycm.completers.completer import Completer
from ycm.server import responses
import logging

RUBY_COMPLETER='/Users/chenyh/prog/ruby/ruby-completer/rcompl.rb'

class RubyCompleter( Completer ):
	def __init__(self, user_options):
		super(RubyCompleter, self).__init__(user_options)
                self.__logger = logging.getLogger( __name__ )

	def SupportedFiletypes( self ):
		""" Just ruby """
		return [ 'ruby' ]

	def ComputeCandidatesInner( self, request_data ):
		filename = request_data[ 'filepath' ]
		if not filename:
			return
                self.__logger.info("HERE ComputeCandidates")



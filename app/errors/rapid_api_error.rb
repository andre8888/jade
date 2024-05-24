class RapidApiError < StandardError
	attr_reader :msg

	def initialize(msg)
		super
		@msg = msg
	end
end
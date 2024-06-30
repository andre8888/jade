class NeighborhoodFilter
	include ActiveModel::Model

	attr_accessor :location, :property_types,
	              :min_price, :max_price, :min_baths, :max_baths,
	              :min_beds, :max_beds, :min_sq, :max_sq

	def initialize
	end
end

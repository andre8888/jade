class Address < ApplicationRecord
	validates_presence_of :street1
	validates_presence_of :city
	validates_presence_of :state
	validates_presence_of :zipcode

	before_save :normalize_address

	attr_readonly :street1, :street2, :city, :state, :zipcode

	def to_s
		"#{street1}#{street2.nil? ? "" : " #{street2}"}, #{city}, #{state} #{zipcode}"
	end

	def normalize_address
		lat_lon = Geocoder.coordinates(self.to_s)
		Rails.logger.error("geocode error: #{self.to_s}") unless lat_lon.present?
		self.latitude = lat_lon[0]
		self.longitude = lat_lon[1]
		self.state.upcase!
	end

	def self.transform(address)
		location = Geocoder.search(address)
		Rails.logger.error("geocode error: #{address}") unless location.present?

		{
			street1: location.first.street_address,
			street2: location.first.address_components_of_type(:subpremise)&.first&.fetch('short_name'),
			city: location.first.city,
			state: location.first.state_code,
			zipcode: location.first.postal_code
		}
	end
end

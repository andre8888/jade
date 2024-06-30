class Property < ApplicationRecord
	belongs_to :address
	validates :address, presence: true

	has_one :statistic

	def normalized_attributes
		{
			property: self.slice(
				:sale_price,
				:sale_estimate,
				:num_beds,
				:num_baths,
				:living_area,
				:year_built,
				:zillow_url,
				:property_tax_rate,
				:monthly_hoa,
				:monthly_insurance
			),
			address: self.address.slice(
				:street1,
				:street2,
				:city,
				:state,
				:zipcode,
				:country
			),
			statistics: self.statistic.slice(
				:monthly_median_rent,
				:monthly_min_rent,
			 	:monthly_max_rent,
			 	:avg_daily_rate,
			 	:occupancy_rate,
			 	:projected_revenue
			)
		}.as_json
	end
end

require 'json'

class NeighborhoodController < ApplicationController
	include NeighborhoodHelper

	layout 'dashboard'

	def new
	end

	def search
		search_params = params[:neighborhood][:search]
		@filter = NeighborhoodFilter.new
		@filter.location = search_params[:location]
		@filter.property_types = search_params[:property_types]
		@filter.min_price = search_params[:min_price]
		@filter.max_price = search_params[:max_price]
		@filter.min_baths = search_params[:min_baths]
		@filter.max_baths = search_params[:max_baths]
		@filter.min_beds = search_params[:min_beds]
		@filter.max_beds = search_params[:max_beds]
		@filter.min_sq = search_params[:min_sq]
		@filter.max_sq = search_params[:max_sq]

		zillow_service = RapidApi::ZillowService.new(true)
		@properties = []

		# seed property data
		# if @filter.location == 'Gatlinburg, TN, USA'
		# 	data = File.read "neighborhood.json"
		# 	data_hash = JSON.parse(data)
		# 	results = data_hash['props']
		# 	results.each do | row |
		# 		property = zillow_service.get_property_by_zillow_id(row['zpid'])
		# 		Rails.logger.info("Seed Neighborhood - found property: #{property}")
		# 		@properties.push(property) if property.present?
		# 	end
		# end

		if @properties.empty?
			begin
				@properties = zillow_service.get_neighborhood(@filter.location,
				                                              @filter.property_types,
				                                              @filter.min_sq,
				                                              @filter.max_sq,
				                                              @filter.min_price,
				                                              @filter.max_price,
				                                              @filter.min_beds,
				                                              @filter.max_beds,
				                                              @filter.min_baths,
				                                              @filter.max_baths)

			rescue RapidApiError => e
				puts e.message
			end
		end

		respond_to do | format |
			format.turbo_stream do
				render turbo_stream: [
					turbo_stream.update("properties", partial: "neighborhood/properties", locals: { properties: @properties, filter: @filter }),
					turbo_stream.action(:scroll_to, "properties"),
				# turbo_stream.after(
				# 	"properties",
				# 	helpers.javascript_tag(%(
				#     let table = new DataTable('#testing');
				#   ))
				# )
				]
			end
		end
	end
end

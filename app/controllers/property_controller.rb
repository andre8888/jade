require 'json'

class PropertyController < ApplicationController
	include PropertyHelper

	layout 'dashboard'

	def new
	end

	def search
		full_address = params[:property][:address][:street1]
		market_strategy = params[:property][:market_strategy]

		response = {}

		# seed property data
		data = File.read "properties.json"
		data_hash = JSON.parse(data)
		data_hash.each do | property |
			if property['address'] == full_address
				response = property['body']
				break
			end
		end

		if response.empty?
			zillow_service = RapidApi::ZillowService.new(true, market_strategy)
			begin
				response = zillow_service.run(full_address)
			rescue RapidApiError => e
				puts e.message
			end
		end

		render json: { data: response }, status: :ok
	end
end

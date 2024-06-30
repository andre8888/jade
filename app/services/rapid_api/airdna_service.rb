require 'uri'
require 'net/http'
require 'httparty'
require 'logger'

# This service handles all operations around AirDNA API.
class RapidApi::AirdnaService
	RAPID_API_AIRDNA_HOST = 'airdna1.p.rapidapi.com'
	RAPID_API_AIRDNA_TOKEN = Rails.application.credentials.rapid[:airdna_token]

	def initialize(debug = false)
		@debug = debug
		@logger = Logger.new(STDOUT)
		@logger.level = @debug? Logger::DEBUG : Logger::INFO
		@headers = {
			'X-RapidAPI-Key' => RAPID_API_AIRDNA_TOKEN,
			'X-RapidAPI-Host' => RAPID_API_AIRDNA_HOST
		}
	end

	def populate_adr_rate(property)
		return if property.statistic&.avg_daily_rate.present? &&
			property.statistic&.occupancy_rate.present? &&
			property.statistic&.projected_revenue.present?

		num_beds = property.num_beds
		num_beds = 6 if property.num_beds > 6
		num_baths = property.num_baths
		num_baths = 6 if property.num_baths > 6
		num_guests = num_beds * 2
		num_guests = 20 if num_guests > 20

		url = "https://#{RAPID_API_AIRDNA_HOST}/rentalizer?address=#{CGI.escape(property.address.to_s)}&bedrooms=#{num_beds}&bathrooms=#{num_baths}&accommodates=#{num_guests}"
		raw_response = HTTParty.get(url, headers: @headers)
		response = JSON.parse(raw_response.body, symbolize_names: true)
		@logger.debug("populate_adr_rate response: #{response}")
		raise RapidApiError.new('bad response') if response.nil?

		average_daily_rate = response[:data][:property_stats][:adr][:ltm].to_i
		occupancy = response[:data][:property_stats][:occupancy][:ltm].to_f
		projected_revenue = response[:data][:property_stats][:revenue][:ltm].to_i

		if property.statistic.present?
			property.statistic.update!(
				avg_daily_rate: average_daily_rate,
				occupancy_rate: occupancy,
				projected_revenue: projected_revenue)
		else
			property.create_statistic!(
				avg_daily_rate: average_daily_rate,
				occupancy_rate: occupancy,
				projected_revenue: projected_revenue)
		end
	end
end

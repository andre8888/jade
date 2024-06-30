require 'uri'
require 'net/http'
require 'httparty'
require 'logger'

class RapidApi
	include ActiveModel::Model
	include ScrapeHelper

	ZILLOW_URL = 'https://www.zillow.com'
	RAPID_API_ZILLOW_HOST = 'zillow-com1.p.rapidapi.com'
	RAPID_API_ZILLOW_TOKEN = Rails.application.credentials.rapid[:zillow_token]

	MARKET_STRATEGY = {
		STR: 'str',
		LTR: 'ltr',
	}

	PROPERTY_TYPE = {
		SINGLE_FAMILY: 'SingleFamily',
		MULTI_FAMILY: 'MultiFamily',
		APARTMENT: 'Condo',
		TOWNHOUSE: 'Townhouse'
	}

	def initialize(market_strategy, use_rentometer: false)
		@debug = false # enable headless
		@run_both_strategy = true

		@logger = Logger.new(STDOUT)
		@logger.level = @debug? Logger::DEBUG : Logger::INFO

		@market_strategy = market_strategy
		@use_rentometer = use_rentometer
		@headers = {
			'X-RapidAPI-Key' => RAPID_API_ZILLOW_TOKEN,
			'X-RapidAPI-Host' => RAPID_API_ZILLOW_HOST
		}
	end

	def run(full_address)
		run_timer = TimeUp.start :rapid_api_run

		# get all property details
		property_timer = TimeUp.start :rapid_get_property
		property_details_response = get_property(address: full_address)
		num_beds = property_details_response[:bedrooms]
		num_baths = property_details_response[:bathrooms]
		@logger.info("property_details_response: #{property_details_response}")
		property_timer.stop

		# get estimated sales price
		sales_estimates_timer = TimeUp.start :rapid_get_sales_estimates
		sales_estimates_response = get_sales_estimates(property_details_response[:zpid])
		@logger.info("sales_estimates_response: #{sales_estimates_response}")
		sales_estimates_timer.stop

		threads = []

		# get estimated rent
		rent_estimates_response = {}
		rent_estimates_timer = TimeUp.start :rapid_get_rent_estimates
		threads << Thread.new do
			if @market_strategy == MARKET_STRATEGY[:LTR] || @run_both_strategy
				rent_estimates_response = get_rent_estimates(
					zpid: property_details_response[:zpid],
					property_type: property_details_response[:property_type],
					address: full_address,
					num_beds: num_beds,
					num_baths: num_baths,
					living_area: property_details_response[:living_area])
				@logger.info("rent_estimates_response: #{rent_estimates_response}")
			end
			rent_estimates_timer.stop
		end

		# get estimated daily rate
		adr_estimates_response = {}
		adr_estimates_timer = TimeUp.start :rapid_get_adr_estimates
		threads << Thread.new do
			if @market_strategy == MARKET_STRATEGY[:STR] || @run_both_strategy
				adr_estimates_response = get_adr_estimates(full_address, num_beds, num_baths)
				@logger.info("adr_estimates_response: #{adr_estimates_response}")
			end
			adr_estimates_timer.stop
		end

		ThreadsWait.all_waits(*threads)
		run_timer.stop
		TimeUp.print_summary

		property_details_response.merge(
			sales_estimates_response.merge(
				rent_estimates_response.merge(
					adr_estimates_response
				)
			)
		)
	end

	def get_property(zpid: nil, property_url: nil, address: nil)
		params = nil
		if zpid
			params = "zpid=#{zpid}"
		elsif property_url
			params = "property_url=#{property_url}"
		elsif address
			params = "address=#{CGI.escape(address)}"
		end
		raise RapidApiError.new('Missing params') if params.nil?

		url = "https://#{RAPID_API_ZILLOW_HOST}/property?#{params}"
		@logger.debug("get_property url: #{url}")
		raw_response = HTTParty.get(url, headers: @headers)
		response = JSON.parse(raw_response.body, symbolize_names: true)
		@logger.debug("get_property response: #{response}")
		raise RapidApiError.new('Bad response') if response.nil?

		{
			zpid: response[:zpid],
			property_link: "#{ZILLOW_URL}/#{response[:url]}",
			address: format_address(response[:address]),
			sale_price: (response[:price] || 0).to_i,
			bedrooms: (response[:bedrooms] || 0).to_i,
			bathrooms: (response[:bathrooms] || 0).to_i,
			living_area: (response[:livingArea] || 0).to_i,
			property_tax_rate: (response[:propertyTaxRate] || 0).to_f,
			hoa: (response[:monthlyHoaFee] || 0).to_i,
			insurance: get_monthly_home_insurance(response[:annualHomeownersInsurance]),
			year_built: (response[:yearBuilt] || 0).to_i,
			property_type: property_type_string(response[:homeType])
		}
	end

	def get_sales_estimates(zpid)
		url = "https://#{RAPID_API_ZILLOW_HOST}/zestimateHistory?zpid=#{zpid}"
		@logger.debug("get_sales_estimates url: #{url}")
		raw_response = HTTParty.get(url, headers: @headers)
		response = JSON.parse(raw_response.body, symbolize_names: true)
		@logger.debug("get_sales_estimates response: #{response}")
		raise RapidApiError.new('Bad response') if response.nil?

		{
			market_value: response.last[:v].to_i
		}
	end

	def get_rent_estimates(zpid: -1, property_type: PROPERTY_TYPE[:SINGLE_FAMILY], address: '', num_beds: 0, num_baths: 0, living_area: 0)
		min_sq = living_area - 100
		max_sq = living_area + 100
		radius = 0.5 # diameter in miles. The max and value is 0.5, and the low value is 0.05. The default value is 0.5

		if @use_rentometer
			rentometer = Rentometer.new(@debug)
			rentometer_response = rentometer.get_rent_estimates(address, num_beds, num_baths, living_area)
			# rentometer_response = ScrapeHelper.parse_response(rentometer_response)
			@logger.debug("rentometer_response: #{rentometer_response}")
			raise RapidApiError.new('Bad response') if rentometer_response.nil?

			median = rentometer_response[:median]
			min = rentometer_response[:percentile_25]
			max = rentometer_response[:percentile_75]
		else
			params = "propertyType=#{property_type}&address=#{CGI.escape(address)}&d=#{radius}&beds=#{num_beds}&baths=#{num_baths}&sqftMin=#{min_sq}&sqftMax=#{max_sq}"
			url = "https://#{RAPID_API_ZILLOW_HOST}/rentEstimate?#{params}"
			@logger.debug("get_rent_estimates url: #{url}")
			raw_response = HTTParty.get(url, headers: @headers)
			response = JSON.parse(raw_response.body, symbolize_names: true)
			@logger.debug("get_rent_estimates response: #{response}")
			raise RapidApiError.new('Bad response') if response.nil?

			median = (response[:median] || 0).to_i
			min = (response[:lowRent] || 0).to_i
			max = (response[:highRent] || 0).to_i

			if median == 0 && min == 0 && max == 0
				# fallback: try to using historical
				historical_rent = get_historical_rent_estimates(zpid)
				median = min = max = historical_rent
			end
		end

		{
			rent_estimate: median,
			rent_median: median,
			rent_min: min,
			rent_max: max
		}
	end

	def get_historical_rent_estimates(zpid)
		url = "https://#{RAPID_API_ZILLOW_HOST}/valueHistory/localRentalRates?zpid=#{zpid}"
		@logger.debug("get_historical_rent_estimates url: #{url}")
		raw_response = HTTParty.get(url, headers: @headers)
		response = JSON.parse(raw_response.body, symbolize_names: true)
		@logger.debug("get_historical_rent_estimates response: #{response}")
		raise RapidApiError.new('Bad response') if response.nil?

		response[:chartData].last[:points].last[:y].to_i
	end

	def get_adr_estimates(address, num_beds, num_baths)
		airdna = Airdna.new(@debug, true)
		adr_resp = airdna.get_adr_rate(address, num_beds, num_baths)
		@logger.debug("airdna_response: #{adr_resp}")
		raise RapidApiError.new('Bad response') if adr_resp.nil?
		raise RapidApiError.new('Missing ADR') if !adr_resp.has_key?(:occupancy) || !adr_resp.has_key?(:average_daily_rate) || !adr_resp.has_key?(:projected_revenue)

		{
			average_daily_rate: adr_resp[:average_daily_rate],
			occupancy_rate: adr_resp[:occupancy],
			projected_revenue: adr_resp[:projected_revenue]
		}
	end

	private

	def format_address(addr_attributes)
		return '' unless addr_attributes
		"#{addr_attributes[:streetAddress]}, #{addr_attributes[:city]}, #{addr_attributes[:state]} #{addr_attributes[:zipcode]}}"
	end

	def get_monthly_home_insurance(annual_insurance)
		((annual_insurance || 0).to_i) / 12
	end

	def property_type_string(value)
		#PROPERTY_TYPE.key(value) // to get key back
		PROPERTY_TYPE[value.to_sym]
	end
end

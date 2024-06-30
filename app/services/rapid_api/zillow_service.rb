require 'uri'
require 'net/http'
require 'httparty'
require 'logger'

# This service handles all operations around Zillow API.
class RapidApi::ZillowService
	ZILLOW_URL = 'https://www.zillow.com'
	RAPID_API_ZILLOW_HOST = 'zillow-com1.p.rapidapi.com'
	RAPID_API_ZILLOW_TOKEN = Rails.application.credentials.rapid[:zillow_token]
	MAX_RESULTS = 50

	PROPERTY_TYPE = {
		SINGLE_FAMILY: 'SingleFamily',
		MULTI_FAMILY: 'MultiFamily',
		APARTMENT: 'Condo',
		TOWNHOUSE: 'Townhouse'
	}

	def initialize(debug = false, market_strategy = nil)
		@debug = debug
		@market_strategy = market_strategy
		@logger = Logger.new(STDOUT)
		@logger.level = @debug ? Logger::DEBUG : Logger::INFO
		@headers = {
			'X-RapidAPI-Key' => RAPID_API_ZILLOW_TOKEN,
			'X-RapidAPI-Host' => RAPID_API_ZILLOW_HOST
		}
		@airdna_service = RapidApi::AirdnaService.new(@debug)
	end

	def run(full_address)
		run_timer = TimeUp.start :zillow_service_run

		# get all property details
		property_timer = TimeUp.start :zillow_service_get_property
		property = get_property_by_address(full_address)
		property_timer.stop

		# get estimated sales price
		sales_estimates_timer = TimeUp.start :zillow_service_get_sales_estimates
		populate_sales_estimates(property)
		sales_estimates_timer.stop

		# get estimated rent
		rent_estimates_timer = TimeUp.start :zillow_service_get_rent_estimates
		populate_rent_estimates(property)
		rent_estimates_timer.stop

		# get estimated daily rate
		adr_estimates_timer = TimeUp.start :zillow_service_get_adr_estimates
		@airdna_service.populate_adr_rate(property)
		adr_estimates_timer.stop

		run_timer.stop
		TimeUp.print_summary

		property.normalized_attributes
	end

	def get_property_by_address(address = nil)
		raise RapidApiError.new('missing address') if address.nil?

		normalized_address = Address.transform(address)
		@logger.debug("normalized address: #{normalized_address}")
		property = Property.joins(:address).where(addresses: normalized_address).first
		if property.present?
			@logger.debug("found property: #{property}")
			return property
		end

		response = nil
		begin
			response = get_property_search("address=#{CGI.escape(address)}")
		rescue RapidApiError => e
			# USE CASE: handle zillow bug where ridge becomes rdge
			if normalized_address[:street1].include? 'Ridge'
				address.gsub!('Ridge', 'Rdge')
				normalized_address = Address.transform(address)
				@logger.debug("re-normalized address: #{normalized_address}")
				response = get_property_search("address=#{CGI.escape(address)}")
			end
		end

		create_property(response, normalized_address)
	end

	def get_property_by_zillow_id(zillow_id = nil)
		raise RapidApiError.new('missing zillow id') if zillow_id.nil?

		property = Property.where(zillow_id: zillow_id).first
		if property.present?
			@logger.debug("found property: #{property}")
			return property
		end

		response = get_property_search("zpid=#{zillow_id}")
		address = "#{response[:address][:streetAddress]}, #{response[:address][:city]}, #{response[:address][:state]} #{response[:address][:zipcode]}}"
		normalized_address = Address.transform(address)
		@logger.debug("normalized address: #{normalized_address}")

		create_property(response, normalized_address)
	end

	def get_neighborhood(location,
	                     property_types,
	                     min_sq,
	                     max_sq,
	                     min_price,
	                     max_price,
	                     min_beds,
	                     max_beds,
	                     min_baths,
	                     max_baths)
		raise RapidApiError.new('missing location') if location.nil?

		params = "location=#{CGI.escape(location)}&status_type=ForSale&isAuction=false&page=1"
		params += "&home_type=#{CGI.escape(property_types.join(','))}" if property_types.present?
		params += "&sqftMin=#{min_sq}" if min_sq.present?
		params += "&sqftMax=#{max_sq}" if max_sq.present?
		params += "&minPrice=#{min_price}" if min_price.present?
		params += "&maxPrice=#{max_price}" if max_price.present?
		params += "&bedsMin=#{min_beds}" if min_beds.present?
		params += "&bedsMax=#{max_beds}" if max_beds.present?
		params += "&bathsMin=#{min_baths}" if min_baths.present?
		params += "&bathsMax=#{max_baths}" if max_baths.present?
		Rails.logger.info("params: #{params}")

		properties = []
		response = get_property_extended_search(params)
		total_pages = response[:totalPages]
		results_per_page = response[:resultsPerPage]
		total_count = response[:totalResultCount]

		raise RapidApiError.new('too many properties, narrow your search!') if total_count > MAX_RESULTS

		results = response[:props]
		Rails.logger.info("total_pages: #{total_pages}")
		Rails.logger.info("results_per_page: #{results_per_page}")
		Rails.logger.info("total_count: #{total_count}")

		total_pages.times.each do | page |
			Rails.logger.info("page: #{page}")
			if page > 0
				params.gsub!("page=#{page}", "page=#{page + 1}")
				Rails.logger.info("params: #{params}")
				response = get_property_extended_search(params)
				results = response[:props]
				Rails.logger.info("results: #{results}")
			end

			results.each do | item |
				# throttle every sec
				property = get_property_by_zillow_id(item[:zpid].to_s)
				sleep 1
				populate_sales_estimates(property)
				sleep 1
				populate_rent_estimates(property)
				@airdna_service.populate_adr_rate(property)

				properties.push(property)
			end
		end

		if properties.count != total_count
			@logger.debug("mismatched total results: #{properties.count}(current) vs #{total_count}(expected)")
		end
		@logger.debug("total properties in neighborhood: #{properties.count}")

		properties
	end

	def populate_sales_estimates(property)
		return if property.sale_estimate.present?

		url = "https://#{RAPID_API_ZILLOW_HOST}/zestimateHistory?zpid=#{property.zillow_id}"
		raw_response = HTTParty.get(url, headers: @headers)
		response = JSON.parse(raw_response.body, symbolize_names: true)
		@logger.debug("populate_sales_estimates response: #{response}")
		raise RapidApiError.new('bad response') unless response.present?

		property.update!(sale_estimate: response.last[:v].to_i)
	end

	def populate_rent_estimates(property)
		return if property.statistic&.monthly_min_rent.present? &&
			property.statistic&.monthly_max_rent.present? &&
			property.statistic&.monthly_median_rent.present?

		min_sq = property.living_area - 100
		max_sq = property.living_area + 100
		radius = 0.5 # diameter in miles. The max and value is 0.5, and the low value is 0.05. The default value is 0.5

		params = "propertyType=#{property.property_type}&address=#{CGI.escape(property.address.to_s)}&d=#{radius}&beds=#{property.num_beds.to_i}&baths=#{property.num_baths.to_i}&sqftMin=#{min_sq.to_i}&sqftMax=#{max_sq.to_i}"
		url = "https://#{RAPID_API_ZILLOW_HOST}/rentEstimate?#{params}"
		raw_response = HTTParty.get(url, headers: @headers)
		response = JSON.parse(raw_response.body, symbolize_names: true)
		@logger.debug("populate_rent_estimates response: #{response}")
		raise RapidApiError.new('Bad response') unless response.present?

		median = (response[:median] || 0).to_i
		min = (response[:lowRent] || 0).to_i
		max = (response[:highRent] || 0).to_i

		if median == 0 && min == 0 && max == 0
			# fallback: try to using historical
			median = min = max = get_rent_estimate_history(property)
		end

		if property.statistic.present?
			property.statistic.update!(monthly_min_rent: min, monthly_max_rent: max, monthly_median_rent: median)
		else
			property.create_statistic!(monthly_min_rent: min, monthly_max_rent: max, monthly_median_rent: median)
		end
	end

	def get_rent_estimate_history(property)
		url = "https://#{RAPID_API_ZILLOW_HOST}/valueHistory/localRentalRates?zpid=#{property.zillow_id}"
		raw_response = HTTParty.get(url, headers: @headers)
		response = JSON.parse(raw_response.body, symbolize_names: true)
		@logger.debug("get_rent_estimate_history response: #{response}")
		raise RapidApiError.new('Bad response') unless response.present?

		response[:chartData] && response[:chartData].last&.fetch(:points)&.last&.fetch(:y)&.to_i || 0
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
		# PROPERTY_TYPE.key(value) // to get key back
		PROPERTY_TYPE[value.to_sym]
	end

	def create_property(response, normalized_address)
		property = Property.new(
			zillow_id: response[:zpid].to_s,
			zillow_url: "#{ZILLOW_URL}#{response[:url]}",
			property_type: property_type_string(response[:homeType]),
			property_tax_rate: (response[:propertyTaxRate] || 0).to_f,
			num_beds: (response[:bedrooms] || 0).to_i,
			num_baths: (response[:bathrooms] || 0).to_i,
			year_built: (response[:yearBuilt] || 0).to_i,
			living_area: (response[:livingArea] || 0).to_i,
			sale_price: (response[:price] || 0).to_i,
			monthly_hoa: (response[:monthlyHoaFee] || 0).to_i,
			monthly_insurance: get_monthly_home_insurance(response[:annualHomeownersInsurance])
		)
		property.build_address(normalized_address)
		if property.save
			@logger.debug("created property successfully: #{property}")
			property
		else
			@logger.debug("failed to property: #{property}")
			raise RapidApiError.new('failed to create property')
		end
	end

	def get_property_extended_search(params)
		url = "https://#{RAPID_API_ZILLOW_HOST}/propertyExtendedSearch?#{params}"
		raw_response = HTTParty.get(url, headers: @headers)
		response = JSON.parse(raw_response.body, symbolize_names: true)
		@logger.debug("get_property_extended_search response: #{response}")
		raise RapidApiError.new('bad response') unless response.present?

		response
	end

	def get_property_search(params)
		url = "https://#{RAPID_API_ZILLOW_HOST}/property?#{params}"
		raw_response = HTTParty.get(url, headers: @headers)
		response = JSON.parse(raw_response.body, symbolize_names: true)
		@logger.debug("get_property_search response: #{response}")
		raise RapidApiError.new('bad response') unless response.present?

		response
	end
end

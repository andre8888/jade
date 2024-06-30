require 'httparty'
require 'puppeteer-ruby'

class Calculator
	include ActiveModel::Model
	include ScrapeHelper

	# accessor get method
	attr_reader :property_types, :min_sq, :max_sq, :min_price, :max_price,
							:min_beds, :max_beds, :min_baths, :max_baths

	# accessor set method
	attr_writer :property_types, :min_sq, :max_sq, :min_price, :max_price,
							:min_beds, :max_beds, :min_baths, :max_baths

	def initialize(
		property_types: nil,
		min_sq: nil,
		max_sq: nil,
		min_price: nil,
		max_price: nil,
		min_beds: nil,
		max_beds: nil,
		min_baths: nil,
		max_baths: nil)
		@logger = Logger.new(STDOUT)
		@logger.level = @debug? Logger::DEBUG : Logger::INFO

		@property_types = property_types
		@min_sq = min_sq
		@max_sq = max_sq
		@min_price = min_price
		@max_price = max_price
		@min_beds = min_beds
		@max_beds = max_beds
		@min_baths = min_baths
		@max_baths = max_baths
	end

	def scrape_rent

	rescue StandardError => e
		puts "HTTP Request failed (#{ e.message })"
	end
end

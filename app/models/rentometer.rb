require 'httparty'
require 'puppeteer-ruby'

class Rentometer
	include ActiveModel::Model
	include ScrapeHelper

	RENTOMETER_URL = 'https://www.rentometer.com'
	RENTOMETER_TOKEN = Rails.application.credentials.rentometer[:token]
	EMAIL = Rails.application.credentials.rentometer[:email]
	PWD = Rails.application.credentials.rentometer[:pwd]

	def initialize(debug = false, use_api = false)
		@debug = debug
		@use_api = use_api
		@logger = Logger.new(STDOUT)
		@logger.level = @debug ? Logger::DEBUG : Logger::INFO
	end

	def get_rent_estimates(full_address, bedrooms, baths, living_area)
		baths = '1.5+' if baths > 1

		if @use_api
			# use rentometer api - api doesn't accept living area
			# paid subscription with limited quota
			api_rent(full_address, bedrooms, baths)
		else
			# scrape rentometer site
			scrape_rent(full_address, bedrooms, baths, living_area)
		end
	end

	def api_rent(full_address, bedrooms, baths)
		params = "api_key=#{RENTOMETER_TOKEN}&address=#{CGI.escape(full_address)}&bedrooms=#{bedrooms}&baths=#{CGI.escape(baths)}"
		url = "#{RENTOMETER_URL}/api/v1/summary?#{params}"
		raw_response = HTTParty.get(url)
		JSON.parse(raw_response.body, symbolize_names: true)
	end

	def scrape_rent(full_address, bedrooms, baths, living_area)
		results = {}

		baths = 1.5 if baths == '1.5+'
		bedrooms = 6 if bedrooms > 6
		min_sq = living_area - 100
		max_sq = living_area + 100

		headless = !@debug
		Puppeteer.launch(headless: headless, slow_mo: 50, args:
			%w[--no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage]
		) do | browser |
			page = browser.new_page
			page.viewport = Puppeteer::Viewport.new(width: 1280, height: 800)
			page.extra_http_headers = { 'Accept-Language': 'en-US,en;q=0.9' }
			page.set_user_agent(ScrapeHelper::USER_AGENT)
			page.goto("#{RENTOMETER_URL}/accounts/sign_in", wait_until: 'domcontentloaded')
			page.wait_for_selector('.card-signin')
			# page.screenshot(path: "url.png")

			form = page.query_selector('form.new_user')
			email_input = form.query_selector('input#user_email')
			email_input.click
			page.keyboard.type_text(EMAIL)
			pwd_input = form.query_selector('input#user_password')
			pwd_input.click
			page.keyboard.type_text(PWD)
			login_button = form.query_selector('input[type=submit]')
			login_button.click
			# page.screenshot(path: "login.png")

			page.wait_for_navigation(wait_until: headless ? 'networkidle0' : 'load')
			form = page.query_selector('form#address_unified_search_form')
			# page.screenshot(path: "search.png")
			address_input = form.query_selector('input#address_unified_search_address')
			address_input.click
			page.keyboard.type_text(full_address)
			beds_input = form.query_selector('select#address_unified_search_bed_style')
			beds_input.select(bedrooms.to_s)
			baths_input = form.query_selector('select#address_unified_search_baths')
			baths_input.select(baths.to_s)
			sq_min_input = form.query_selector('input#address_unified_search_min_sqft')
			sq_min_input.click
			page.keyboard.type_text(min_sq.to_s)
			sq_max_input = form.query_selector('input#address_unified_search_max_sqft')
			sq_max_input.click
			page.keyboard.type_text(max_sq.to_s)
			analyze_button = form.query_selector('input[type=submit]')
			analyze_button.click

			# check if any warning alert
			begin
				page.wait_for_selector('.alert-warning', visible: true)
				alert = page.query_selector('.container')
				alert_msg = alert.eval_on_selector('div.alert-warning', 'div => div.innerText')
				@logger.debug("rentometer has warning on search filter being too narrow!")
				if alert_msg.include? 'Looks like your filters may have created too narrow of a search'
					form = page.query_selector('form#address_unified_search_form')
					form.eval_on_selector('input#address_unified_search_min_sqft', 'input => input.value = ""')
					form.eval_on_selector('input#address_unified_search_max_sqft', 'input => input.value = ""')
					form.eval_on_selector('select#address_unified_search_baths', 'select => select.value = ""')
					analyze_button = form.query_selector('input[type=submit]')
					analyze_button.click
				end
			rescue => e
				@logger.debug("rentometer has no warning on search filter being too narrow!")
			end

			page.wait_for_selector('#active-results-container')
			stats = page.query_selector_all('.box-stats-row .box-stats')
			stats.each do | stat |
				title = stat.eval_on_selector('span', 'span => span.innerText')
				title = title.downcase
				if title == 'average'
					div = stat.query_selector('.box-num')
					results[:mean] = div.eval_on_selector('abbr', 'abbr => abbr.innerText')
				elsif title == 'median'
					div = stat.query_selector('.box-num')
					results[:median] = div.eval_on_selector('abbr', 'abbr => abbr.innerText')
				elsif title == '25th percentile'
					div = stat.query_selector('.box-num')
					results[:percentile_25] = div.eval_on_selector('abbr', 'abbr => abbr.innerText')
				elsif title == '75th percentile'
					div = stat.query_selector('.box-num')
					results[:percentile_75] = div.eval_on_selector('abbr', 'abbr => abbr.innerText')
				end
			end
		end

		results[:mean] = trim_text(results[:mean])
		results[:median] = trim_text(results[:median])
		results[:percentile_25] = trim_text(results[:percentile_25])
		results[:percentile_75] = trim_text(results[:percentile_75])
		results
	rescue StandardError => e
		puts "HTTP Request failed (#{ e.message })"
	end
end

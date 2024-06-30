require 'watir'
require 'nokogiri'
require 'puppeteer-ruby'
require 'open-uri'

class Airdna
	include ActiveModel::Model
	include ScrapeHelper

	AIRDNA_URL = 'https://app.airdna.co'
	EMAIL = Rails.application.credentials.airdna[:email]
	PWD = Rails.application.credentials.airdna[:pwd]
	USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.181 Safari/537.36'

	RAPID_API_AIRDNA_HOST = 'airdna1.p.rapidapi.com'
	RAPID_API_AIRDNA_TOKEN = Rails.application.credentials.rapid[:airdna_token]

	def initialize(debug = false, use_api = false)
		@debug = debug
		@use_api = use_api
		@headers = {
			'X-RapidAPI-Key' => RAPID_API_AIRDNA_TOKEN,
			'X-RapidAPI-Host' => RAPID_API_AIRDNA_HOST
		}
		@logger = Logger.new(STDOUT)
		@logger.level = @debug ? Logger::DEBUG : Logger::INFO
	end

	def get_adr_rate(full_address, num_beds, num_baths)
		num_beds = 6 if num_beds > 6
		num_baths = 6 if num_baths > 6
		num_guests = num_beds * 2
		num_guests = 20 if num_guests > 20

		if @use_api
			url = "https://#{RAPID_API_AIRDNA_HOST}/rentalizer?address=#{CGI.escape(full_address)}&bedrooms=#{num_beds}&bathrooms=#{num_baths}&accommodates=#{num_guests}"
			@logger.debug("get_adr_rate url: #{url}")
			raw_response = HTTParty.get(url, headers: @headers)
			response = JSON.parse(raw_response.body, symbolize_names: true)
			@logger.debug("get_adr_rate response: #{response}")
			raise RapidApiError.new('Bad response') unless response.present?

			{
				average_daily_rate: response[:data][:property_stats][:adr][:ltm].to_i,
				occupancy: response[:data][:property_stats][:occupancy][:ltm].to_f * 100,
				projected_revenue: response[:data][:property_stats][:revenue][:ltm].to_i
			}
		else
			scrape(full_address, num_beds, num_baths, num_guests)
		end
	end

	def scrape(full_address, num_beds, num_baths, num_guests)
		results = {}

		headless = !@debug
		Puppeteer.launch(headless: headless, slow_mo: 50, args:
			%w[--no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage]
		) do | browser |
			page = browser.new_page
			page.viewport = Puppeteer::Viewport.new(width: 1280, height: 800)
			page.extra_http_headers = { 'Accept-Language': 'en-US,en;q=0.9' }
			page.set_user_agent(USER_AGENT)
			page.goto("#{AIRDNA_URL}/data/login", wait_until: 'domcontentloaded')
			page.wait_for_selector('form.MuiBox-root', visible: true)
			# page.screenshot(path: "url.png")

			form = page.query_selector('form.MuiBox-root')
			email_input = form.query_selector('input#login-email')
			email_input.click
			page.keyboard.type_text(EMAIL)
			pwd_input = form.query_selector('input#login-password')
			pwd_input.click
			page.keyboard.type_text(PWD)
			login_button = form.query_selector('button')
			page.wait_for_navigation(wait_until: headless ? 'networkidle0' : 'load') do
				login_button.click
			end
			# page.screenshot(path: "login.png")

			page.wait_for_selector('.MuiAutocomplete-root', visible: true)
			market_selector = page.query_selector('.MuiBox-root > .MuiGrid-root .MuiGrid-root:nth-child(2) button')
			market_selector.click
			market_option = page.query_selector('.MuiBox-root > .MuiGrid-root .MuiGrid-root:nth-child(2) .MuiBox-root .MuiBox-root .MuiBox-root li:nth-child(2)')
			market_option.click
			page.wait_for_timeout 3000

			page.wait_for_selector('.MuiAutocomplete-root', visible: true)
			search_input = page.query_selector('input.MuiAutocomplete-input')
			search_input.click
			page.keyboard.type_text(full_address)
			page.wait_for_timeout 3000
			page.wait_for_selector('ul.MuiAutocomplete-listbox', visible: true)
			last_row = page.query_selector('ul.MuiAutocomplete-listbox li:last-child')
			page.wait_for_navigation(wait_until: headless ? 'networkidle0' : 'load') do
				last_row.click
			end
			# page.screenshot(path: "search.png")

			# page.goto("#{AIRDNA_URL}/data/rentalizer?address=#{CGI.escape(full_address)}")
			page.wait_for_selector('[data-testid=BedOutlinedIcon]', visible: true)
			config = page.query_selector('main.MuiBox-root .MuiBox-root > .MuiBox-root .MuiBox-root .MuiBox-root .MuiBox-root .MuiBox-root:nth-child(4)')
			bed_select = config.query_selector('[data-testid=BedOutlinedIcon]')
			bed_select.click
			bed_option = page.query_selector("li.MuiButtonBase-root[data-value='#{num_beds}']")
			bed_option.click

			bath_select = config.query_selector('[data-testid=BathTubIcon]')
			bath_select.click
			bath_option = page.query_selector("li.MuiButtonBase-root[data-value='#{num_baths}']")
			bath_option.click

			guest_select = config.query_selector('[data-testid=PersonOutlineOutlinedIcon]')
			guest_select.click
			guest_option = page.query_selector("li.MuiButtonBase-root[data-value='#{num_guests}']")
			guest_option.click

			update_button = config.query_selector('button')
			update_button.click

			page.wait_for_timeout 5000 # wait for client side reload on the stats
			page.wait_for_selector('main.MuiBox-root .MuiGrid-container .MuiGrid-item.MuiGrid-grid-desktop-4', visible: true)
			stats = page.query_selector_all('.MuiGrid-container .MuiGrid-item.MuiGrid-grid-desktop-4')
			stats.each do | stat |
				title = stat.eval_on_selector('p', 'p => p.innerText')
				if title == 'Occupancy'
					results[:occupancy] = stat.eval_on_selector('h3', 'h3 => h3.innerText')
				elsif title == 'Average Daily Rate'
					results[:average_daily_rate] = stat.eval_on_selector('h3', 'h3 => h3.innerText')
				elsif title == 'Projected Revenue'
					results[:projected_revenue] = stat.eval_on_selector('h3', 'h3 => h3.innerText')
				end
			end
		end

		results[:average_daily_rate] = trim_text(results[:average_daily_rate])
		results[:occupancy] = results[:occupancy].gsub('%', '').to_i if results[:occupancy]
		if results[:projected_revenue]
			results[:projected_revenue] = results[:projected_revenue].gsub('$', '')
			if results[:projected_revenue].end_with? 'K'
				results[:projected_revenue] = results[:projected_revenue].to_f * 1000
			end
		end

		results
	end
end

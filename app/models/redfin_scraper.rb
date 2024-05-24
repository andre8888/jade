require 'watir'
require 'nokogiri'
require 'puppeteer-ruby'
require 'open-uri'

class RedfinScraper
  include ActiveModel::Model
  include ScrapeHelper

  REDFIN_URL = 'https://www.redfin.com'
  USERNAME = 'efo2ng@gmail.com'

  def login(page)
    page.goto("#{REDFIN_URL}/login", wait_until: 'domcontentloaded')
    page.wait_for_selector('.form-inner-container')
    form = page.query_selector('[data-rf-form-name=LoginPageForm_SignInForm]')
    email_input = form.query_selector('[data-rf-test-name=input]')
    email_input.click
    page.keyboard.type_text('')
  end

  def get_property_url(full_address)
    results = {}
    results[:body] = {}

    Puppeteer.launch(headless: false, slow_mo: 50, args:
      %w[--no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage]
    ) do |browser|
      page = browser.new_page
      page.viewport = Puppeteer::Viewport.new(width: 1280, height: 800)
      page.extra_http_headers = {'Accept-Language': 'en-US,en;q=0.9'}
      page.set_user_agent(ScrapeHelper::USER_AGENT)
      page.default_navigation_timeout = 3000


      page.goto(REDFIN_URL, wait_until: 'domcontentloaded')
      page.wait_for_selector('.homepageTabContainer')

      login_link = page.query_selector('[data-rf-test-name=CombinedLoginLink]')
      login_link.click
      form = page.query_selector('form[data-rf-form-name=LoginDialog]')
      email_input = form.query_selector('[data-rf-test-name=Text]')
      email_input.click
      page.keyboard.type_text('')
      email_input.press('Enter')
      # login_link = page.query_selector('[data-rf-test-id=SignInLink]')
      # login_link.click
      form = page.query_selector('form.SearchBoxForm')
      search_input = form.query_selector('input.search-input-box')
      search_input.click
      page.keyboard.type_text(full_address)
      search_input.press('Enter')
      page.wait_for_navigation
      on_home_details_page = page.query_selector('.route-HomeDetails')
      if on_home_details_page
        results[:body][:property_link] = page.url
      else
        on_search_page = page.query_selector('.route-SearchPage')
        if on_search_page
          selected_card = page.query_selector('[data-rf-test-id=photos-view] .HomeCardContainer.selectedHomeCard')
          results[:body][:property_link] = selected_card.eval_on_selector('a', 'a => a.getAttribute("href")')
        end
      end
      browser.close
    end

    results
  end

  def get_property_details(listing_url)
    results = {}
    results[:body] = {}

    puts "listing url: #{listing_url}"
    doc = Nokogiri::HTML5(URI.open(listing_url))
    puts "doc: #{doc}"
    results[:body][:address] = doc.css('[data-rf-test-id=abp-homeinfo-homeaddress] .full-address').text
    puts "address: #{results[:body][:address]}"
    sale_price = trim_text(doc.css('[data-rf-test-id=abp-price] .statsValue').text)
    results[:body][:sale_price] = sale_price
    bedrooms = doc.css('[data-rf-test-id=abp-beds] .statsValue').text
    puts "bedrooms: #{bedrooms}"
    results[:body][:bedrooms] = bedrooms.to_i if bedrooms
    bathrooms = doc.css('[data-rf-test-id=abp-baths] .statsValue').text
    results[:body][:bathrooms] = bathrooms.to_f if bathrooms
    results[:body][:living_area] = trim_text(doc.css('[data-rf-test-id=abp-sqFt] .statsValue').text)

    calc_summary = doc.css('[data-rf-test-name=mc-summary] .CalculatorSummary .colorBarLegend .Row')
    calc_summary.each do |summary|
      if summary.css('.Row--header').text.include? 'HOA'
        results[:body][:hoa] = trim_text(summary.css('.Row--content').text)
      elsif summary.css('.Row--header').text.include? 'insurance'
        results[:body][:insurance] = trim_text(summary.css('.Row--content').text)
      elsif summary.css('.Row--header').text.include? 'Property taxes'
        property_tax_monthly = trim_text(summary.css('.Row--content').text)
        results[:body][:property_tax] = property_tax_monthly
        if property_tax_monthly && sale_price
          results[:body][:property_tax_rate] = ((Float(property_tax_monthly * 12) / Float(sale_price)) * 100).round(2)
        end
      end
    end

    public_facts = doc.css('[data-rf-test-id=publicRecords] .PublicRecordsBasicInfo .facts-table .table-row')
    public_facts.each do |fact|
      if fact.css('.table-label').text == 'Year Built'
        year_built = Float(fact.css('.table-value').text) rescue nil
        results[:body][:year_built] = trim_text(year_built)
      end
    end
    unless results[:body][:year_built]
      about_this_home_facts = doc.css('[data-rf-test-id=mhi-housesummary] .KeyDetailsV2 .KeyDetailsTable .keyDetails-row .keyDetails-value')
      about_this_home_facts.each do |fact|
        if fact.text.starts_with? 'Built in'
          results[:body][:year_built] = trim_text(fact.text.gsub('Built in ', '').first(4))
        end
      end
    end

    puts "details: #{results}"

    results
  end
end
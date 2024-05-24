require 'httparty'

class BridgeData
  include ActiveModel::Model

  BRIDGE_DATA_URL = 'https://api.bridgedataoutput.com/api/v2'
  BRIDGE_DATA_TOKEN = Rails.application.credentials.bridge_data[:token]

  def get_rent_estimates(full_address, bedrooms = nil, baths = nil, living_area = nil)
    zestimates_params = "access_token=#{BRIDGE_DATA_TOKEN}&limit=1&near=#{full_address}"
    zestimates_url = "#{BRIDGE_DATA_URL}/zestimates_v2/zestimates?#{zestimates_params}"

    HTTParty.get(zestimates_url)
  end
end
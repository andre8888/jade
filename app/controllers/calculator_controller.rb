require 'json'

class CalculatorController < ApplicationController
  def index
  end

  def new
    @calculator = Calculator.new
  end

  def run
    full_address = params[:calculator][:address][:street1]
    market_strategy = params[:calculator][:market_strategy]

    response = {}

    # seed property data
    data = File.read "properties.json"
    data_hash = JSON.parse(data)
    data_hash.each do |property|
      if property['address'] == full_address
        response = property['body']
        break
      end
    end

    if response.empty?
      rapid = RapidApi.new(market_strategy, use_rentometer: true)
      begin
        response = rapid.run(full_address)
      rescue RapidApiError => e
        puts e.message
      end
    end

    render json: { data: response }, status: :ok
  end

  private

  def calculator_params
    params.require(:calculator).permit(
        address: [:street1, :street2, :city, :state, :zipcode, :country]
    )
  end
end
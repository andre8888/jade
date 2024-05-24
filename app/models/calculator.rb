class Calculator
  include ActiveModel::Model

  attr_accessor :address,
                :market_strategy,
                :sale_price,
                :down_payment,
                :loan_amount,
                :interest_rate,
                :loan_length,
                :monthly_mortgage,
                :closing_cost,
                :rehab_cost,
                :furniture_cost,
                :initial_cash_investment,
                :avg_daily_rate,
                :occupancy_rate,
                :est_monthly_rent,
                :maintenance,
                :property_tax,
                :annual_insurance,
                :property_management_fees,
                :monthly_hoa,
                :booking_lodging_fees,
                :monthly_supplies,
                :monthly_utilities,
                :monthly_expenses,
                :monthly_cash_flow,
                :coc_return,
                :year_1_debt_paydown,
                :appreciation,
                :annualized_roi

  validate :check_address

  def check_address
    unless address.valid?
      errors.add(:address, 'must be complete')
    end
  end

  def run
    street1 = address.street1
    city = address.city
    state = address.state
    zipcode = address.zipcode
    country = address.country
  end
end
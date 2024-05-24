class AddMarketValueOnRents < ActiveRecord::Migration[7.0]
  def change
    add_column :rents, :market_value, :float, after: :building_type
  end
end

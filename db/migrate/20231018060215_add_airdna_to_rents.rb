class AddAirdnaToRents < ActiveRecord::Migration[7.0]
  def change
    add_column :rents, :projected_revenue, :float, after: :rentometer_nearby_comps_url
    add_column :rents, :occupancy, :float, after: :rentometer_nearby_comps_url
    add_column :rents, :average_daily_rate, :float, after: :rentometer_nearby_comps_url
  end
end

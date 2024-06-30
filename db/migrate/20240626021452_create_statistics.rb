class CreateStatistics < ActiveRecord::Migration[7.0]
  def change
    create_table :statistics do |t|
      t.float :monthly_min_rent
      t.float :monthly_max_rent
      t.float :monthly_median_rent
      t.float :avg_daily_rate
      t.float :occupancy_rate
      t.float :projected_revenue

      t.timestamps
    end
  end
end

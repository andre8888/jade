class CreateRents < ActiveRecord::Migration[7.0]
  def change
    create_table :rents do |t|
      t.string :address
      t.decimal :latitude
      t.decimal :longitude
      t.decimal :bedrooms
      t.decimal :baths
      t.string :building_type
      t.decimal :zillow_mean
      t.decimal :mean
      t.decimal :median
      t.decimal :min
      t.decimal :max
      t.decimal :percentile_25
      t.decimal :percentile_75
      t.decimal :std_dev
      t.string :rentometer_token
      t.string :rentometer_quickview_url
      t.string :rentometer_pro_report_url
      t.string :rentometer_nearby_comps_url

      t.timestamps
    end
  end
end

class CreateProperties < ActiveRecord::Migration[7.0]
  def change
    create_table :properties do |t|
      t.string :property_type
      t.float :property_tax_rate
      t.float :num_beds
      t.float :num_baths
      t.integer :year_built
      t.float :living_area
      t.float :lot_area
      t.float :sale_price
      t.float :sale_estimate
      t.float :monthly_hoa
      t.float :monthly_insurance
      t.string :zillow_id
      t.string :zillow_url

      t.timestamps
    end
  end
end

class ChangeDecimalToFloatOnRents < ActiveRecord::Migration[7.0]
  def change
    change_column :rents, :latitude, :float
    change_column :rents, :longitude, :float
    change_column :rents, :bedrooms, :float
    change_column :rents, :baths, :float
    change_column :rents, :zillow_mean, :float
    change_column :rents, :mean, :float
    change_column :rents, :median, :float
    change_column :rents, :min, :float
    change_column :rents, :max, :float
    change_column :rents, :percentile_25, :float
    change_column :rents, :percentile_75, :float
    change_column :rents, :std_dev, :float
  end
end

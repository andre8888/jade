class AddPropertyToStatistic < ActiveRecord::Migration[7.0]
  def change
    add_reference :statistics, :property, index: true, null: false, foreign_key: true
  end
end

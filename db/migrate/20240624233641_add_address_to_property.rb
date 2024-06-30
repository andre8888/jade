class AddAddressToProperty < ActiveRecord::Migration[7.0]
  def change
    add_reference :properties, :address, index: true, null: false, foreign_key: true
  end
end

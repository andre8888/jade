class Address < ApplicationRecord
  validates_presence_of :street1
  validates_presence_of :city
  validates_presence_of :state
  validates_presence_of :zipcode
end

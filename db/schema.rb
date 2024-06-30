# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2024_06_26_021610) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "hstore"
  enable_extension "plpgsql"

  create_table "addresses", force: :cascade do |t|
    t.string "street1"
    t.string "street2"
    t.string "city"
    t.string "state"
    t.string "zipcode"
    t.string "country", default: "US"
    t.float "latitude"
    t.float "longitude"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "properties", force: :cascade do |t|
    t.string "property_type"
    t.float "property_tax_rate"
    t.float "num_beds"
    t.float "num_baths"
    t.integer "year_built"
    t.float "living_area"
    t.float "lot_area"
    t.float "sale_price"
    t.float "sale_estimate"
    t.float "monthly_hoa"
    t.float "monthly_insurance"
    t.string "zillow_id"
    t.string "zillow_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "address_id", null: false
    t.index ["address_id"], name: "index_properties_on_address_id"
  end

  create_table "statistics", force: :cascade do |t|
    t.float "monthly_min_rent"
    t.float "monthly_max_rent"
    t.float "monthly_median_rent"
    t.float "avg_daily_rate"
    t.float "occupancy_rate"
    t.float "projected_revenue"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "property_id", null: false
    t.index ["property_id"], name: "index_statistics_on_property_id"
  end

  add_foreign_key "properties", "addresses"
  add_foreign_key "statistics", "properties"
end

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

ActiveRecord::Schema[7.0].define(version: 2023_10_18_060215) do
  create_table "addresses", charset: "utf8mb4", force: :cascade do |t|
    t.string "street1"
    t.string "street2"
    t.string "city"
    t.string "state"
    t.string "zipcode"
    t.string "country"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "rents", charset: "utf8mb4", force: :cascade do |t|
    t.string "address"
    t.float "latitude"
    t.float "longitude"
    t.float "bedrooms"
    t.float "baths"
    t.string "building_type"
    t.float "market_value"
    t.float "zillow_mean"
    t.float "mean"
    t.float "median"
    t.float "min"
    t.float "max"
    t.float "percentile_25"
    t.float "percentile_75"
    t.float "std_dev"
    t.string "rentometer_token"
    t.string "rentometer_quickview_url"
    t.string "rentometer_pro_report_url"
    t.string "rentometer_nearby_comps_url"
    t.float "average_daily_rate"
    t.float "occupancy"
    t.float "projected_revenue"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end

# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2019_01_11_085546) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "uuid-ossp"

  create_table "admin_users", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "username"
    t.string "displayname"
    t.integer "rights"
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "timezone"
    t.string "currency", default: "USD"
  end

  create_table "bonds", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.text "comment"
    t.boolean "refunded", default: false
    t.uuid "order_id"
    t.uuid "vendor_id"
    t.index ["order_id"], name: "index_bonds_on_order_id"
    t.index ["vendor_id"], name: "index_bonds_on_vendor_id"
  end

  create_table "btc_addresses", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "address"
    t.uuid "order_id"
    t.text "pgp_signature"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "payment_method_id"
    t.index ["order_id"], name: "index_btc_addresses_on_order_id"
  end

  create_table "btc_rates", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.integer "payment_method_id"
    t.text "code"
    t.decimal "rate"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payment_method_id", "code"], name: "index_btc_rates_on_payment_method_id_and_code", unique: true
  end

  create_table "categories", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name"
    t.integer "sortorder", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "feedbacks", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "placedby_id"
    t.uuid "placedon_id"
    t.uuid "order_id"
    t.text "rating", default: ""
    t.text "feedback", default: ""
    t.text "response", default: ""
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_feedbacks_on_order_id"
    t.index ["placedby_id", "order_id"], name: "index_feedbacks_on_placedby_id_and_order_id", unique: true
    t.index ["placedby_id"], name: "index_feedbacks_on_placedby_id"
    t.index ["placedon_id"], name: "index_feedbacks_on_placedon_id"
  end

  create_table "generated_addresses", force: :cascade do |t|
    t.string "btc_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "loaded_to_market", default: false
    t.text "pgp_signature"
    t.string "address_type"
    t.index ["btc_address"], name: "index_generated_addresses_on_btc_address"
  end

  create_table "locations", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "description"
  end

  create_table "locations_products", id: false, force: :cascade do |t|
    t.uuid "location_id"
    t.uuid "product_id"
    t.index ["location_id"], name: "index_locations_products_on_location_id"
    t.index ["product_id"], name: "index_locations_products_on_product_id"
  end

  create_table "message_refs", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "otherparty_id"
    t.uuid "message_id"
    t.string "direction"
    t.integer "unseen", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "messages", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.text "body"
    t.uuid "recipient_id"
    t.uuid "sender_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "multipay_groups", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "primary_order_id"
  end

  create_table "network_fees", force: :cascade do |t|
    t.integer "weeknum"
    t.decimal "fee", default: "0.0"
    t.index ["weeknum"], name: "index_network_fees_on_weeknum"
  end

  create_table "news_posts", force: :cascade do |t|
    t.datetime "post_date"
    t.text "message"
  end

  create_table "order_payouts", force: :cascade do |t|
    t.uuid "order_id"
    t.string "payout_type"
    t.string "btc_address"
    t.decimal "btc_amount"
    t.boolean "paid", default: false
    t.string "txid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id"
    t.index ["order_id"], name: "index_order_payouts_on_order_id"
  end

  create_table "orders", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "buyer_id"
    t.uuid "vendor_id"
    t.integer "quantity", default: 0
    t.string "status", default: ""
    t.decimal "btc_price", default: "0.0"
    t.datetime "dispatched_on"
    t.datetime "finalize_at"
    t.integer "finalize_extended", default: 0
    t.text "address", default: ""
    t.text "notes", default: ""
    t.uuid "product_id"
    t.uuid "shippingoption_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "unseen", default: 1
    t.string "title"
    t.boolean "deleted_by_vendor", default: false
    t.boolean "deleted_by_buyer", default: false
    t.string "declined_reason"
    t.decimal "payment_received", default: "0.0"
    t.decimal "commission", default: "0.0"
    t.decimal "refund_requested_fraction", precision: 3, scale: 2, default: "0.0"
    t.uuid "unitprice_id"
    t.text "exchange_rate"
    t.boolean "locked", default: false
    t.decimal "admin_finalized_refund_fraction", precision: 3, scale: 2, default: "0.0"
    t.text "description", default: ""
    t.datetime "finalized_at"
    t.boolean "admin_set_paid", default: false
    t.integer "payment_method_id"
    t.decimal "payment_unconfirmed", default: "0.0"
    t.boolean "archived_by_buyer", default: false
    t.boolean "archived_by_vendor", default: false
    t.uuid "multipay_group_id"
    t.boolean "fe_required", default: false
    t.text "vendor_profile"
    t.index ["buyer_id"], name: "index_orders_on_buyer_id"
    t.index ["product_id"], name: "index_orders_on_product_id"
    t.index ["shippingoption_id"], name: "index_orders_on_shippingoption_id"
    t.index ["vendor_id"], name: "index_orders_on_vendor_id"
  end

  create_table "payment_methods", force: :cascade do |t|
    t.string "name"
    t.string "logo_filename"
    t.boolean "enabled", default: true
    t.string "code"
    t.index ["code"], name: "index_payment_methods_on_code", unique: true
    t.index ["name"], name: "index_payment_methods_on_name", unique: true
  end

  create_table "payment_methods_products", id: false, force: :cascade do |t|
    t.integer "payment_method_id"
    t.uuid "product_id"
    t.index ["payment_method_id"], name: "index_payment_methods_products_on_payment_method_id"
    t.index ["product_id"], name: "index_payment_methods_products_on_product_id"
  end

  create_table "payouts", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "order_id"
    t.datetime "order_created"
    t.string "username"
    t.string "order_btc_address"
    t.decimal "order_btc_price"
    t.string "payout_btc_address"
    t.decimal "payout_btc_amount"
    t.decimal "commission"
    t.boolean "paid", default: false
    t.string "txid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "payout_type"
    t.integer "order_payout_id"
    t.boolean "market_updated", default: false
    t.string "address_type"
    t.integer "payout_schedule", array: true
    t.boolean "confirmed", default: false
    t.string "user_timezone"
    t.string "displayname"
    t.integer "vsize"
    t.integer "fee"
    t.boolean "hold", default: false
    t.index ["order_btc_address", "payout_type"], name: "index_payouts_on_order_btc_address_and_payout_type", unique: true
    t.index ["order_id", "username"], name: "index_payouts_on_order_id_and_username", unique: true
    t.index ["order_payout_id"], name: "index_payouts_on_order_payout_id", unique: true
  end

  create_table "products", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "title"
    t.text "description", default: ""
    t.decimal "stock", precision: 10, scale: 3, default: "0.0"
    t.uuid "category_id"
    t.uuid "vendor_id"
    t.uuid "from_location_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "deleted", default: false
    t.string "image1_file_name"
    t.string "image1_content_type"
    t.integer "image1_file_size"
    t.datetime "image1_updated_at"
    t.text "unitdesc"
    t.boolean "hidden", default: false
    t.boolean "available_for_sale", default: true
    t.integer "orders_count", default: 0
    t.string "image2_file_name"
    t.string "image2_content_type"
    t.integer "image2_file_size"
    t.datetime "image2_updated_at"
    t.string "image3_file_name"
    t.string "image3_content_type"
    t.integer "image3_file_size"
    t.datetime "image3_updated_at"
    t.integer "primary_image"
    t.boolean "fe_enabled", default: false
    t.integer "sortorder", default: 0
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["from_location_id"], name: "index_products_on_from_location_id"
    t.index ["vendor_id"], name: "index_products_on_vendor_id"
  end

  create_table "products_shippingoptions", id: false, force: :cascade do |t|
    t.uuid "product_id"
    t.uuid "shippingoption_id"
    t.index ["product_id"], name: "index_products_shippingoptions_on_product_id"
    t.index ["shippingoption_id"], name: "index_products_shippingoptions_on_shippingoption_id"
  end

  create_table "shippingoptions", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "description", default: ""
    t.decimal "price", precision: 10, scale: 2, default: "0.0"
    t.uuid "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "currency", default: "USD"
  end

  create_table "ticket_messages", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "ticket_id"
    t.text "message"
    t.text "response"
    t.boolean "message_seen", default: false
    t.boolean "response_seen", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tickets", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "title"
    t.uuid "user_id"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "unitprices", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.decimal "unit", precision: 10, scale: 2
    t.decimal "price", precision: 10, scale: 2, default: "0.0"
    t.uuid "product_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "currency", default: "USD"
  end

  create_table "users", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "username"
    t.string "displayname"
    t.text "publickey", default: ""
    t.text "profile", default: ""
    t.integer "logincount", default: 0
    t.integer "failedlogincount", default: 0
    t.datetime "lastlogin"
    t.boolean "vendor", default: false
    t.string "password_digest"
    t.string "avatar_file_name"
    t.string "avatar_content_type"
    t.integer "avatar_file_size"
    t.datetime "avatar_updated_at"
    t.text "currency", default: "USD"
    t.text "lastseen"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "timezone"
    t.boolean "disabled", default: false
    t.datetime "disabled_until"
    t.string "payout_btc_address"
    t.boolean "vacation", default: false
    t.string "payout_ltc_address"
    t.integer "payout_schedule", default: [0], array: true
    t.boolean "pgp_2fa", default: false
    t.decimal "commission"
    t.boolean "fe_allowed", default: false
    t.index ["displayname"], name: "index_users_on_displayname", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

end

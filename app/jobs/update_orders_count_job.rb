# Counter cache is enabled so products.orders_count variable is automatically incremented by rails every time an order created.
# This variable is used for sorting most popular products. However it includes orders in states 'before confirmed' and 'payment pending'
# so popularity influenced by creating lots of orders in those states. It seems like some buyers will create 'before confirmed' orders
# as a way to get a bitcoin price estimate.
# This job resets all products orders_count based on number of orders that were paid.
# Only count orders in last 4 weeks because we want current popularity, not a product that was popular a year ago that no one is buying currently.
# Rails prevents altering orders_count directly and the functions for adjusting it are not suitable for setting to arbitrary values,
# therefore update using SQL.
# A better solution would be to add another attribute to Product to track this info.
class UpdateOrdersCountJob < ApplicationJob
  queue_as :default

  def perform
    ActiveRecord::Base.connection.execute("UPDATE products SET orders_count = 0;")

    Order.where('created_at > ?', Time.now - 4.week).after_paid.
      select('COUNT(1) AS cnt, product_id').group(:product_id).each do |p|
        ActiveRecord::Base.connection.execute("UPDATE products SET orders_count = #{p.cnt} WHERE id = '#{p.product_id}';")
      end
  end
end

# Show historical count of paid orders each week.
class WeeklyOrderCountReportJob < ApplicationJob
  queue_as :default

  def perform
    Order.after_paid.select('COUNT(1) AS sum, EXTRACT(WEEK FROM created_at) AS week, EXTRACT(YEAR FROM created_at) AS year').
      group('week, year').
      order('year, week').each do |w|
        puts "#{w.year.to_i}/#{w.week.to_i} : #{w.sum}"
    end

  end
end

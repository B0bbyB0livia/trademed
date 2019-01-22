module ApplicationHelper
  # This method is used by views. Application controller has same method defined too.
  def admin_controller?
    controller.class.name.split("::").first=="Admin"
  end

  def currency_format(number, precision=2)
    # Round cent values based on precision, format with commas, but don't show currency symbol.
    number_to_currency(number, unit: "", precision: precision)
  end

  # Vendors save product prices in their preferred currency.
  # When others view these prices, a conversion is done to the current user's preference currency.
  # Do not use this function for conversions related to an order because each order has its own exchange rates.
  def to_users_currency(fromCurrency, price, precision=2)
    fromRate = PaymentMethod.bitcoin.btc_rates.find_by(code: fromCurrency).rate
    toRate = PaymentMethod.bitcoin.btc_rates.find_by(code: current_user.currency).rate
    number_to_currency( (price  * toRate ) / fromRate, unit: "", precision: precision)
  end

  def number_to_range(num, ranges)
    ranges.each do |range|
      if range.include?(num)
        return "#{range.first}-#{range.last}"
      end
    end
    return "over #{ranges.last.last}"
  end

 # For new order form.
 def unitprice_label(unitprice)
    "#{sprintf("%g", unitprice.unit)} #{unitprice.product.unitdesc} - #{to_users_currency(unitprice.currency, unitprice.price)} #{current_user.currency}"
 end

 # The lastseen attribute of a user is a string that logs in UTC the last hour they were active.
 # This converts that string into another string representing the time in the current user's timezone.
 # Historically lastseen was displayed directly in views as UTC for simplicity but nicer to convert to users timezone.
 # lastseen may be nil, so to avoid exception on parse, check this case.
 def lastseen_to_current_users_timezone(lastseen)
   if lastseen
    t = Time.zone.parse(lastseen)
    t.in_time_zone(session_user.timezone).to_s(:FHM)
   else
    "n/a"
   end
 end
end

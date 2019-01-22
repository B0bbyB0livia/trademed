# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)


bitcoin = PaymentMethod.create( name: 'Bitcoin', code: 'BTC' )
# It is not necessary to have an exchange rate, app will still start. Run one of the jobs to set rates asap.
BtcRate.create(code: 'USD', rate: 500, payment_method: bitcoin )

# Example to initialize. The only effect of these records is to show on nav bar.
#(1..53).each{|n| NetworkFee.create(weeknum: n) }

#Category.create([ {name: 'Category1'},{name: 'Category2'} , {name: 'Category3'} ])
#Location.create([ { description: 'Russia' }, { description: 'USA' }, { description: 'World wide' }, { description: 'Canada' } ])

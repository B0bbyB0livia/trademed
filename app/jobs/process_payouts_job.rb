# Ensure you have procedures in place to avoid multiple instances of this running, it is not designed to handle concurrency.
# Assumes exclusive access to wallet to avoid "time of check to time of use" issues.

# This job generates bitcoin/litecoin transactions for the payouts, and saves txids to the local database of payouts.
# Job update_market_order_payouts_job.rb updates the market OrderPayouts with txids so the user knows payment was done.
# This will call UpdateMarketOrderPayouts if a transaction was generated.
# Before running this, ensure a fresh import job has run to get latest new order payouts and update any where the user changed the payout address.

# This job generates a single transaction with multiple outputs if necessary to save on transaction fees (batching).
# In most cases the vendor probably has a payout address configured in their account settings so all their payouts will pay to same bitcoin address.
# A database GROUP BY query sums the amount to pay, grouping by payout address. It is a little more complicated than that because vendor payments
# have an application fee deducted (but not buyer payments).

# For bitcoind < 0.17 the sendmany RPC will always debit an account and the account will need sufficient funds allocated to it, even for default '' account.
# If the order addresses are tagged with an account name, you may need to use the 'move' RPC to allocate the funds to default account to make this job work.
# In bitcoind 0.17 this is not an issue.

# Fees.
# Run the wallet with either static fee rate (paytxfee) or dynamic fees. This job does not set a fee. It uses whatever the wallet is configured for.

# Example:
#   docker-compose run --rm trademed rails r 'ProcessPayoutsJob.perform_now(verbose:1, dry_run:1)'

class ProcessPayoutsJob < ApplicationJob
  queue_as :default

  # TODO add 3rd optional parameter that indicates whether to log to file and call Scriptlog.error, Scriptlog...
  def verbose(type, msg)
    if $verbose
      prefix = case type
                 when :info
                   "+"
                 when :error
                   "!"
                 when :warn
                   "-"
               end
      puts "[#{prefix}] #{msg}"
    end
  end

  def perform(**args)
    username = args[:username]
    order_id = args[:order_id]
    address_type = args[:address_type] || 'BTC'       # default type of payout to process.
    ignore_payout_schedule = args.has_key?(:ignore_payout_schedule)  # each payout has a list of days that limit when payout can be processed. This ignores that.
    dry_run = args.has_key?(:dry_run)
    import = args.has_key?(:import)                  # whether to try importing order payouts from market before processing payments.
    $verbose = args.has_key?(:verbose)
    conf_target = args[:conf_target]
    # If conf_target supplied and it would result in a feerate greater than max_fee_rate, abort and do not generate transaction.
    # This is a safety net to allow admin to review whether use a higher than expected fee.
    max_fee_rate = args[:max_fee_rate]
    vendor_network_fee = args[:vendor_network_fee] || 0.0

    rpc = Payout_bitcoinrpc
    if address_type == 'LTC'
      rpc = Payout_litecoinrpc
    end

    if conf_target && !(1..50).to_a.include?(conf_target)
      verbose(:error, "conf_target needs to be an integer < 51")
      return
    end

    if max_fee_rate && !(0.00001..0.09).include?(max_fee_rate)
      verbose(:error, "max_fee_rate not in allowable range")
      return
    end

    if max_fee_rate && !conf_target
      verbose(:error, "max_fee_rate is only used when conf_target supplied")
      return
    end

    if import
      verbose(:info, "importing order payouts from market")
      # Block until import done because anything imported to be processed on this run.
      ImportOrderPayoutsJob.perform_now
    end

    payouts = Payout.where(paid: false, hold: false).where(address_type: address_type)

    if order_id
      payouts = payouts.where(order_id: order_id)
    end

    if username
      payouts = payouts.where(username: username)
    end

    # Database saves weekdays as per ruby DAYNAMES which has Sunday = 0.
    # Can use Date.today.wday or Time.now.wday. These returns 0 for Sunday and 1 for Monday but day based on UTC.
    # Each vendor may be in different timezone so can't just use servers time for wday. It needs to be based on vendors timezone.
    unless ignore_payout_schedule
      skip_users = []
      payouts.each do |payout|
        if payout.payout_type == 'vendor'
          Time.zone = payout.user_timezone   # change system timezone to calculate wday.
          weekday = Time.zone.now.wday
          unless payout.payout_schedule.include?(weekday)
            skip_users.push(payout.username)
          end
        end
      end
      payouts = payouts.where.not(username: skip_users)
    end

    verbose(:info, "dry-run mode - no transactions will be generated") if dry_run
    verbose(:info, "found #{payouts.count} to pay of type #{address_type}")
    held_payouts = payouts.rewhere(hold:true)
    if held_payouts.count > 0
      verbose(:info, "found #{held_payouts.count} held payouts that will not be paid")
    end

    commission_total = 0.0
    payout_total = 0.0

    if payouts.count > 0
      result = payouts.select('SUM(payout_btc_amount) AS payout_total, SUM(commission) AS commission_total')
      commission_total = result[0].commission_total
      payout_total = result[0].payout_total
    end
    total_required = payout_total + commission_total
    # bitcoins paid to this wallet need a required number of confirmations to contribute to balance.
    balance = rpc.getbalance(::DummyStar, Rails.configuration.blockchain_confirmations)
    getwalletinfo = rpc.getwalletinfo
    txfee = "%.8f" % getwalletinfo["paytxfee"]
    verbose(:info, "transaction fee configured in wallet is #{'%.8f'%txfee}")
    verbose(:warn, "dynamic fees enabled") if getwalletinfo["paytxfee"] == 0.0
    verbose(:info, "funds received to wallet (getbalance RPC): #{balance}")
    verbose(:info, "total funds required to continue (commissions & payouts but not including tx fees): #{total_required}")
    verbose(:info, "total to pay users: #{payout_total}")
    verbose(:info, "total commission amount: #{commission_total}")
    verbose(:info, "vendor network fee: #{'%.8f'%vendor_network_fee}")
    if total_required > balance
      s = "insufficient balance #{balance} in wallet to generate all transactions, requires #{total_required}."
      ScriptLog.error s
      verbose(:error, s)
      verbose(:info, "add at least #{total_required - balance} to the wallet")
      return unless dry_run
    end

    # Buyer payouts have no network fee because it is unfair to charge them a fee on their refund.
    # This complicates calculations because need to also GROUP BY payout_type to identify weather it is a buyer payout.
    resultset = payouts.select('COUNT(payout_btc_address) AS cnt, SUM(payout_btc_amount) AS sum_pay_amount, SUM(commission) as sum_commission, payout_btc_address, payout_type').
                        group(:payout_btc_address, :payout_type)

    resultset.each do |payment|
      fee = payment.payout_type == 'vendor' ? vendor_network_fee : 0.0
      verbose(:info, "to pay (excluding network fee): #{payment.sum_pay_amount}, network fee: #{'%.8f'%fee}, " +
              "to: #{payment.payout_btc_address}, record count: #{payment.cnt}, type: #{payment.payout_type}")
    end

    buyer_resultset = resultset.having(payout_type: "buyer")
    vendor_resultset = resultset.having(payout_type: "vendor")
    buyer_amounts = buyer_resultset.pluck(:payout_btc_address, 'SUM(payout_btc_amount)').to_h
    vendor_amounts = vendor_resultset.pluck(:payout_btc_address, 'SUM(payout_btc_amount)').to_h
    # example pluck result
    #=> {"mn3oydmDskW16ZWLoV8Qe7Av7NsH2Mzp6UH"=>#<BigDecimal:5fe26f8,'0.475E-1',9(18)>, "mfsMmGSPkYyrki79yiX6SQGSV2z3eVyq4C"=>#<BigDecimal:5fe2180,'0.1615E-1',9(18)>,...

    # convert BigDecimals to floats otherwise the RPC call will have strings for the amounts.
    buyer_amounts.transform_values! {|x| x.to_f.round(8) }
    vendor_amounts.transform_values! {|x| (x - vendor_network_fee).to_f.round(8) }

    output_amounts = buyer_amounts.merge(vendor_amounts)

    # To minimize the verbose output a little, only print the separate buyer and vendor hashes if some buyer payment exists.
    # Normally it will only be vendor payments being processed so this won't show anything.
    if buyer_amounts.size > 0
      verbose(:info, "buyer payments JSON: #{buyer_amounts.to_json}")
      if vendor_amounts.size > 0
        verbose(:info, "vendor payments JSON: #{vendor_amounts.to_json}")
      end
    end

    # Show the JSON that will be provided to RPC call.
    if output_amounts.size > 0
      verbose(:info, "JSON RPC: #{output_amounts.to_json}")
    end

    # Catch case were hash merge overwrites a key.
    # It shouldn't occur normally because it would mean a vendor and a customer are both using the same wallet address
    # and the import job will put the payout on hold in that case.
    # If it is legit, you can proceed by processing payments in multiple runs using the filter parameters or putting a payout on hold.
    if resultset.size != output_amounts.size
      s = "aborting. buyer hash and vendor hash both had a shared key (payment address). unable to process payments."
      ScriptLog.error s
      verbose(:error, s)
      return
    end

    # Check for zero or negative payments due to network fee. Only need to check vendor_amounts but may as well do all payments.
    non_positive_payments = output_amounts.select{|addr, amount| amount <= 0 }
    if non_positive_payments.size > 0
      s = "aborting. some payments had non-positive amounts: #{non_positive_payments.to_json}"
      ScriptLog.error s
      verbose(:error, s)
      return
    end

    if conf_target
      result = rpc.estimatesmartfee(conf_target, "ECONOMICAL")
      unless result.has_key?("feerate")
        s = "aborting. conf_target supplied and wallet unable to estimate fees."
        ScriptLog.error s
        verbose(:error, s)
        return
      end
      feerate = result["feerate"]
      verbose(:info, "conf_target=#{conf_target} calculated feerate: #{'%.8f'%feerate}")
      if max_fee_rate && feerate > max_fee_rate
        s = "aborting. the conf_target would result in fee %.8f which is greater than max_fee_rate %.8f" % [feerate, max_fee_rate]
        ScriptLog.warn s
        verbose(:warn, s)
        return
      end
    end

    return if dry_run || payouts.size == 0

    # Use database transaction so you set paid = true, then call bitcoin api, if api returns error, rollback paidout to false.
    #  Don't want to make a payment and then have a problem updating paid=true because then multiple payouts could happen.
    txid = nil
    Payout.transaction do
      payouts.update_all(paid: true, txid: 'pending')
      # If rpc returns json error code it will raise an exception.
      # The confirmation param is to try avoid making payments when the incoming funds haven't had sufficient confirmations.
      txid = rpc.sendmany(
          ::DummyBlank,                                         # from 0.17 this must be empty string.
          output_amounts,
          Rails.configuration.blockchain_confirmations,
          "output_count:#{output_amounts.size}",                # comment string.
          [],
          true,   # replacable BIP125
          )
    end

    # Put this outside the transaction because don't want this to ever cause a rollback.
    if txid
      ScriptLog.info("txid: #{txid}")
      verbose(:info, "txid: #{txid}")
      # The scope object payouts will only have records with paid:false so new query needed.
      Payout.where(txid: 'pending').update_all(txid: txid, updated_at: Time.now)
      if commission_total > 0
        ScriptLog.info("commission is #{commission_total.to_f.round(8)} [rounded]")
      end
      UpdateMarketOrderPayoutsJob.perform_now()
    else
      ScriptLog.error("RPC call failed")
    end
  end
end

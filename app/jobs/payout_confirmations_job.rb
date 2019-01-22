# Since this job is only run when admin views payout index, it is possible that a payouts transaction is no longer
# in the mempool when this runs. In that case getrawtransaction will fail and fee , vsize will not be saved.
# To avoid that problem, schedule this job daily, or recode to save_fee after processing payments instead of after being confirmed. Or stop using prune option.
class PayoutConfirmationsJob < ApplicationJob
  queue_as :default

  def save_fee(payout, rpc)
    begin
      tx = rpc.gettransaction(payout.txid)
      fee_in_satoshi = tx['fee'].abs * 100000000
      # This only works for transactions in the mempool if you don't have -txindex set.
      tx = rpc.getrawtransaction(payout.txid, true)
      vsize = tx['vsize']
      payout.update!(fee: fee_in_satoshi, vsize: vsize)
    rescue BitcoinRPC::JSONRPCError
      ScriptLog.error "rpc unable to get info to calculate fee on #{payout.txid}"
    end
  end

  def perform
    ScriptLog.info "Looking unconfirmed payouts to check if they are now confirmed."
    payouts = Payout.where(paid: true, confirmed: false)
    payouts_count = payouts.count
    if payouts_count > 0
      ScriptLog.info "Found #{payouts_count} payouts to check."
    end
    payouts.each do |payout|
      if payout.address_type == 'BTC'
        rpc = Payout_bitcoinrpc
      elsif payout.address_type == 'LTC'
        rpc = Payout_litecoinrpc
      end
      tx = rpc.gettransaction(payout.txid)
      save_fee(payout, rpc) if payout.fee.nil?
      if tx['confirmations'] > 0
        if payout.update(confirmed: true)
          ScriptLog.info "payout id: #{payout.id}, txid: #{payout.txid} is now confirmed."
        else
          ScriptLog.error "payout id: #{payout.id} error updating payout confirmed:true."
        end
      elsif tx.has_key? 'replaced_by_txid'
        tx_new = rpc.gettransaction(tx['replaced_by_txid'])
        # Update txid and force update_market_order_payouts.rb to re-update market.
        payout.update(txid: tx['replaced_by_txid'], market_updated: false)
        save_fee(payout, rpc)
        if tx_new['confirmations'] > 0
          if payout.update(confirmed: true)
            ScriptLog.info "payout id: #{payout.id}, txid: #{payout.txid} is now confirmed. txid was replaced."
          else
            ScriptLog.error "payout id: #{payout.id} error updating payout confirmed:true."
          end
        end
      end
    end
  end
end

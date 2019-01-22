# Mostly copied from MessagesController with much removed since we are only viewing.
class Admin::MessagesController < ApplicationController
  before_action :require_admin

  # List of all conversations the specified user had with other parties.
  # Every interaction with another user is a converstation. There is only one conversation thread with each other user (very simple).
  def conversations
    # GET /messages/:id
    @user = User.find(params[:id])
    # Array of MessageRef objects but due to GROUP BY they only have attributes otherparty_id, newest_message_date, cnt, unseen_cnt.
    @conversations = MessageRef.select('otherparty_id, max(created_at) newest_message_date, count(1) as cnt, sum(unseen) as unseen_cnt').
                     group('otherparty_id').
                     where(user: @user).
                     order('unseen_cnt desc, newest_message_date desc')  # Primary sort groups with unread messages so they appear at top.

    # Additional list is generated to help with seeing deleted messages (refs).
    all_recipients = Message.select('recipient_id').where(sender: @user).group('recipient_id').unscope(:order).collect{|row| User.find(row['recipient_id']) }
    all_senders = Message.select('sender_id').where(recipient: @user).group('sender_id').unscope(:order).collect{|row| User.find(row['sender_id']) }
    @parties = all_recipients | all_senders
  end

  def show_conversation
    # GET /messages/:id/:otherparty_id
    @user = User.find(params[:id])
    @otherparty = User.find(params[:otherparty_id])

    # This is a ruby group_by not SQL GROUP BY.
    # Returns hash where keys are string from strftime and value is an array of messages that have same value
    # so messages grouped by day they were created. We sort the hash keys in the view.
    @message_daygroups = @user.message_refs.where(otherparty: @otherparty).group_by do |msg|
      msg.created_at.in_time_zone(admin_user.timezone).strftime('%F')
    end

    # undeleted_messages is the list of messages that have references pointing to them.
    undeleted_messages = @user.message_refs.where(otherparty: @otherparty).collect{|msg_ref| msg_ref.message }
    all_messages = Message.where(sender: [@user, @otherparty]).where(recipient: [@user, @otherparty])
    @deleted_messages = all_messages - undeleted_messages
    @deleted_message_daygroups = @deleted_messages.group_by do |msg|
      msg.created_at.in_time_zone(admin_user.timezone).strftime('%F')
    end
  end


end

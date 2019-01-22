class MessagesController < ApplicationController
  before_action :require_login

  # List of all conversations with other users.
  # Every interaction with another user is a converstation. There is only one conversation thread with each other user (very simple).
  def conversations
    # GET /messages
    # Array of MessageRef objects but due to GROUP BY they only have attributes otherparty_id, newest_message_date, cnt, unseen_cnt.
    # sent_anything is boolean and says whether any message ref exists that is sent to otherparty. This info is used when showing whether recipient has seen messages.
    @conversations = MessageRef.select("otherparty_id, max(created_at) newest_message_date, count(1) as cnt, sum(unseen) as unseen_cnt, bool_or(direction = 'sent') sent_anything").
                     group('otherparty_id').
                     where(user: current_user).
                     order('unseen_cnt desc, newest_message_date desc')  # Primary sort groups with unread messages so they appear at top.
  end

  def show_conversation
    # GET /messages/:id  where id belongs to the other party.
    # The show view has a form for creating a new message.
    # The conversations index and the user profile page both have links to this resource but the profile page link is the only one
    # that should ever result in unauthorized to send. Instead of redirecting back there, render the form anyway but put a alert message on the page
    # so the user doesn't waste time writing out a message only to find that on submission it is unauthorized.
    otherparty = User.find(params[:id])
    if !current_user.is_authorized_to_send_message_to(otherparty)
      flash.now[:alert] = 'It is not possible for you to send a message to this recipient. In general, only buyers can send messages to vendors.'
    end
    @message = Message.new
    #  Above returns ActiveRecord::RecordNotFound exception if id invalid.
    @message.recipient = otherparty  # This parameter is checked for authorization in create method.

    # By viewing this page, it means all messages with otherparty get marked seen.
    current_user.message_refs.where(otherparty: otherparty).unseen.update_all unseen: 0

    # This is a ruby group_by not SQL GROUP BY.
    # Returns hash where keys are string from strftime and value is an array of messages that have same value
    # so messages grouped by day they were created. We sort the hash keys in the view.
    @message_daygroups = current_user.message_refs.where(otherparty: otherparty).group_by do |msg|
      msg.created_at.in_time_zone(current_user.timezone).strftime('%F')
    end

    @gpg_id_str = Gpgkeyinfo.read_key(otherparty.publickey)
  end

  # There is more documentation about messages in user model associations.
  def create
    # POST /messages
    @message = Message.new(message_params)
    @message.sender = current_user
    # if @message.recipient_id doesn't reference any user (due to parameter tamper) rails doesn't raise exception (referential integrity fails). So check manually.
    if not @message.recipient.present?
      raise NotAuthorized
    end
    if !current_user.is_authorized_to_send_message_to(@message.recipient)
      raise NotAuthorized
    end
    # These two lines setup the variables for show_converstation view which gets rendered on validation failure of message.
    otherparty = @message.recipient
    @message_daygroups = current_user.message_refs.where(otherparty: otherparty).group_by{ |msg| msg.created_at.beginning_of_day }

    # Save a single copy of the message. Create two references to it for each party. This allows deletion by deleting reference.
    Message.transaction do
      # Any exceptions in this block will force a rollback. So if either MessageRef fails to save then message is rolled back.
      if @message.save
        # For the MessageRef with direction "sent", set unseen to 0 so we can sum unseen to count all new messages received.
        MessageRef.new(message: @message, user: current_user, otherparty: @message.recipient, direction: 'sent', unseen: 0).save!
        MessageRef.new(message: @message, user: @message.recipient, otherparty: current_user, direction: 'received', unseen: 1).save!
        redirect_to show_conversation_path(@message.recipient), notice: 'Message was successfully sent'
      else
        render action: 'show_conversation'
      end
    end
  end

  # When deleting, the entire set of messages in conversation is deleted. Currently not implementing single message deletion.
  # DELETE /messages/:id  where id belongs to the other party you want messages deleted.
  # No need to validate parameter because it only effects current user's message refs.
  def delete_conversation
    otherparty = User.find(params[:id])
    current_user.message_refs.where(otherparty: otherparty).destroy_all
    redirect_to conversations_path, notice: 'Messages deleted'
  end

  private
    def message_params
      params.require(:message).permit(:body, :recipient_id)
    end

end

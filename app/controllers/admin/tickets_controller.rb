# Used on market server.
class Admin::TicketsController < ApplicationController
  before_action :require_admin
  before_action :set_ticket, only: [:show, :update]

  def index
    # Sorts by boolean result of comparison. open will be ordered first, then info, closed.
    @tickets = Ticket.order("status='closed', status='info', status='open'").order('created_at DESC, status DESC')
    @tickets = @tickets.page(params[:page])
  end

  def show
    @ticket.ticket_messages.update_all message_seen: true
  end

  def update
    if @ticket.update(ticket_params)
      redirect_to admin_ticket_path(@ticket), notice: 'Support ticket saved'
    else
      render :edit
    end
  end

  # Originally, only users could create tickets/ticket_messages and admins could only respond my updating the response attribute
  # on the ticket_message. But there was no way for admins to contact a user because admins don't have messaging. The easiest solution
  # was to allow admins to create tickets and assign them to a specified user. This way users would see correspondence from admins
  # in their list of support tickets.
  # When the ticket_message is created by admin, the message attribute is left nil because this is only ever set by the user
  # and the admins message is conveyed in the response attribute. When user replies, a new ticket_message is added and the original
  # ticket_message created by the admin will always have message attribute nil. The show screens know not to try render nil message/response
  # attributes. So the message attribute can be described better as user_message and response attribute as admin_message.
  # This ticket system was only meant to be a quick solution to get by initially before coding it better like how messaging is done.
  def new
    @ticket = Ticket.new
    @ticket.user_id = params[:user_id]
    @ticket.ticket_messages.build(response: '', response_seen: false)
  end

  def create
    @ticket = Ticket.new(ticket_params)
    if @ticket.save
      redirect_to admin_ticket_path(@ticket), notice: 'Ticket was created'
    else
      # If admin submitted the form without a message (response attribute), then we need to build one for the view. See model.
      @ticket.ticket_messages.build(response: '', response_seen: false) if @ticket.ticket_messages.empty?
      render :new
    end

  end

  private
    def set_ticket
      @ticket = Ticket.find(params[:id])
    end

    def ticket_params
      # Allow for updating status, and any TicketMessages response attribute.
      # Allow title, user_id for creating new tickets (initiating contact with user).
      params.require(:ticket).permit(:title, :user_id, :status, ticket_messages_attributes: [:id, :response, :response_seen])
    end
end

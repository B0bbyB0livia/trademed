class TicketsController < ApplicationController
  before_action :require_login
  before_action :set_ticket, only: [:show, :update, :destroy]

  def index
    @tickets = current_user.tickets.order('created_at DESC, status DESC')
  end

  def new
    @ticket = Ticket.new
    @ticket.ticket_messages.build(message: '')
  end

  # A ticket has one or more ticket messages. New text is added by adding another ticket message (TM).
  # Using accepts_nested_attributes_for to make saving the TM easier.
  def create
    @ticket = Ticket.new(ticket_params)
    @ticket.user = current_user
    @ticket.status = 'open'
    if @ticket.save
      redirect_to @ticket, notice: 'Ticket was created'
    else
      # If user submitted the form without a message, then we need to build one for the view. See model.
      @ticket.ticket_messages.build(message: '') if @ticket.ticket_messages.empty?
      render :new
    end
  end
 
  def show
    # Form will allow saving a new message.
    @ticket.ticket_messages.build(message: '')
    @ticket.ticket_messages.update_all response_seen: true
  end

  def update
    # Creates a new ticket_message with message attribute set from form field.
    if @ticket.update(ticket_params)
      redirect_to @ticket, notice: 'Support ticket saved'
    else
      render :show
    end
  end

  def destroy
    @ticket.destroy
    redirect_to tickets_path, notice: 'Support ticket was deleted'
  end

  private
    def set_ticket
      @ticket = Ticket.find(params[:id])
      raise NotAuthorized unless @ticket.user == current_user
    end

    # Title is readonly so doesn't matter if user attempts to edit it.
    def ticket_params
      # We only add new TicketMessages, never edit existing ones so no need to allow id in ticket_message_attributes.
      # Since no TicketMessage ids received, no need to check if owned by user.
      params.require(:ticket).permit(:title, :status, ticket_messages_attributes: [:message])
    end
end

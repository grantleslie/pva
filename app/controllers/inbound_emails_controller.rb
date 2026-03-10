class InboundEmailsController < ApplicationController
  before_action :authenticate_user!

  def index
    @inbound_emails = InboundEmail
      .includes(:job)
      .order(received_at: :desc)
      .limit(100)
  end

  def show
    @inbound_email = InboundEmail.find(params[:id])
  end
end
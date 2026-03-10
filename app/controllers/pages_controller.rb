class PagesController < ApplicationController
	def home
		@job = Job.new
	end
	def inbound_emails
		@emails = InboundEmail.all
	end
end
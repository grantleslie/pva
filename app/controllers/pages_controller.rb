class PagesController < ApplicationController
	def home
		@job = Job.new
	end
end
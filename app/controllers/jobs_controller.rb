# app/controllers/jobs_controller.rb
class JobsController < ApplicationController
  before_action :set_job, only: %i[show edit update destroy]

  def index
    @jobs = current_user.jobs.order(created_at: :desc)
  end

  def show
  end

  def new
  end

  def create
    @job = current_user.jobs.new(job_params)

    if @job.save
      redirect_to @job, notice: "Job created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @job.update(job_params)
      redirect_to @job, notice: "Job updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @job.destroy
    redirect_to jobs_path, notice: "Job deleted successfully."
  end

  private

  def set_job
    @job = current_user.jobs.find(params[:id])
  end

  def job_params
    params.require(:job).permit(
      :name,
      :description,
      :job_type,
      :pretty_name,
      :user_email,
      :instructions,
      :status
    )
  end
end
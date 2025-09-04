class Admin::TestsController < Admin::BaseController
  def s3_upload
    @upload = Upload.new
  end

  def s3_create
    @upload = Upload.new(upload_params)
    if @upload.save
      redirect_to admin_test_s3_path, notice: "File uploaded successfully!"
    else
      render :s3_upload
    end
  end

  def active_job
  end

  def trigger_job
    TestJob.perform_later(params[:message] || "Test message")
    redirect_to admin_test_job_path, notice: "Job queued successfully!"
  end

  private

  def upload_params
    params.require(:upload).permit(:file, :title)
  end
end
require "test_helper"

class Admin::TestsControllerTest < ActionDispatch::IntegrationTest
  test "should get s3_upload" do
    get admin_tests_s3_upload_url
    assert_response :success
  end

  test "should get active_job" do
    get admin_tests_active_job_url
    assert_response :success
  end
end

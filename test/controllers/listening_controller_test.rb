require "test_helper"

class ListeningControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get listening_index_url
    assert_response :success
  end
end

require "test_helper"

class NeighborhoodControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get neighborhood_index_url
    assert_response :success
  end
end

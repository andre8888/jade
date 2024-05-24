require "test_helper"

class PropertyControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get property_index_url
    assert_response :success
  end
end

require "test_helper"

class ResourceAbilitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @resource_ability = resource_abilities(:one)
  end

  test "should get index" do
    get resource_abilities_url
    assert_response :success
  end

  test "should get new" do
    get new_resource_ability_url
    assert_response :success
  end

  test "should create resource_ability" do
    assert_difference("ResourceAbility.count") do
      post resource_abilities_url, params: { resource_ability: { active_permissions: @resource_ability.active_permissions, active_restrictions: @resource_ability.active_restrictions } }
    end

    assert_redirected_to resource_ability_url(ResourceAbility.last)
  end

  test "should show resource_ability" do
    get resource_ability_url(@resource_ability)
    assert_response :success
  end

  test "should get edit" do
    get edit_resource_ability_url(@resource_ability)
    assert_response :success
  end

  test "should update resource_ability" do
    patch resource_ability_url(@resource_ability), params: { resource_ability: { active_permissions: @resource_ability.active_permissions, active_restrictions: @resource_ability.active_restrictions } }
    assert_redirected_to resource_ability_url(@resource_ability)
  end

  test "should destroy resource_ability" do
    assert_difference("ResourceAbility.count", -1) do
      delete resource_ability_url(@resource_ability)
    end

    assert_redirected_to resource_abilities_url
  end
end

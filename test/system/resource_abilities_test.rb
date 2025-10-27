# frozen_string_literal: true

require "application_system_test_case"

class ResourceAbilitiesTest < ApplicationSystemTestCase
  setup do
    @resource_ability = resource_abilities(:one)
  end

  test "visiting the index" do
    visit resource_abilities_url
    assert_selector "h1", text: "Resource abilities"
  end

  test "should create resource ability" do
    visit resource_abilities_url
    click_on "New resource ability"

    fill_in "Active permissions", with: @resource_ability.active_permissions
    fill_in "Active restrictions", with: @resource_ability.active_restrictions
    click_on "Create Resource ability"

    assert_text "Resource ability was successfully created"
    click_on "Back"
  end

  test "should update Resource ability" do
    visit resource_ability_url(@resource_ability)
    click_on "Edit this resource ability", match: :first

    fill_in "Active permissions", with: @resource_ability.active_permissions
    fill_in "Active restrictions", with: @resource_ability.active_restrictions
    click_on "Update Resource ability"

    assert_text "Resource ability was successfully updated"
    click_on "Back"
  end

  test "should destroy Resource ability" do
    visit resource_ability_url(@resource_ability)
    click_on "Destroy this resource ability", match: :first

    assert_text "Resource ability was successfully destroyed"
  end
end

# frozen_string_literal: true

require "test_helper"

class RoleTest < ActiveSupport::TestCase
  should "calculate the bit flag" do
    Role::PERMISSIONS.length.times do |idx|
      assert_equal(1 << idx, Role.calculate_direct_permissions_value([Role::PERMISSIONS[idx]]))
      (Role::PERMISSIONS.length - idx).times do |idx2|
        assert_equal((1 << idx) | (1 << (idx2 + idx)), Role.calculate_direct_permissions_value([Role::PERMISSIONS[idx], Role::PERMISSIONS[idx2 + idx]]))
      end
    end
  end
  should "correctly construct" do
    role = create(:role, name: "TestAdmin", parent_role: "Admin", direct_permissions: 1)
    assert_equal("TestAdmin", role.name)
    assert_equal("Admin", role.parent_role)
    # assert_equal(["can_lock_rating"], role.active_direct_permissions)
    # assert_equal(["can_lock_rating"] + Role::ARCHETYPES[:admin].permissions, role.active_permissions)
    assert_equal(["can_lock_rating"] + Role::ARCHETYPES[:admin].permissions, role.active_direct_permissions)
    # assert_equal(["can_lock_rating"] + Role::ARCHETYPES[:admin].permissions, role.active_permissions)
  end
end

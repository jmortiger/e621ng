# frozen_string_literal: true

require "test_helper"

class TagAliasAbilityTest < ActiveSupport::TestCase
  context "A tag alias" do
    setup do
      @mod = create(:moderator_user)
      @mod.init_ability
      @bureaucrat = create(:bureaucrat_user)
      @bureaucrat.init_ability
      @admin = create(:admin_user)
      @admin.init_ability
      CurrentUser.user = @admin
      @user = create(:user, created_at: 1.month.ago)
      @user.init_ability
    end

    context "#approvable_by?" do
      setup do
        @bd = create(:bd_staff_user)
        @bd.init_ability
        @ti = as(@user) { create(:tag_alias, status: "pending") }
        @dnp = as(@bd) { create(:avoid_posting) }
        @ti2 = as(@user) { create(:tag_alias, antecedent_name: @dnp.artist_name, consequent_name: "ccc", status: "pending") }
        @ti3 = as(@user) { create(:tag_alias, antecedent_name: "ddd", consequent_name: @dnp.artist_name, status: "pending") }
      end

      should "not allow creator" do
        assert_equal(false, @user.can?(:approve, @ti))
      end

      should "not allow mods" do
        assert_equal(false, @mod.can?(:approve, @ti))
      end

      should "allow bureaucrats" do
        assert_equal(true, @bureaucrat.can?(:approve, @ti))
      end

      should "allow admins" do
        assert_equal(true, @admin.can?(:approve, @ti))
      end

      context "w/ a dnp antecedent/consequent" do
        should "not allow bureaucrats" do
          assert_equal(false, @bureaucrat.can?(:approve, @ti2))
          assert_equal(false, @bureaucrat.can?(:approve, @ti3))
        end

        should "not allow admins" do
          assert_equal(false, @admin.can?(:approve, @ti2))
          assert_equal(false, @admin.can?(:approve, @ti3))
        end

        should "allow bd staff" do
          assert_equal(true, @bd.can?(:approve, @ti2))
          assert_equal(true, @bd.can?(:approve, @ti3))
        end
      end
    end

    # TODO: Test when status is retired, processing, & queued
    context "#deletable_by?" do
      setup do
        @other_user = create(:user)
        @other_user.init_ability
        @ti_p = as(@user) { create(:tag_alias, antecedent_name: "ti_a0", consequent_name: "ti_c0", status: "pending") }
        @ti_a = as(@user) { create(:tag_alias, antecedent_name: "ti_a1", consequent_name: "ti_c1", status: "active") }
        @ti_o = as(@other_user) { create(:tag_alias, antecedent_name: "ti_a2", consequent_name: "ti_c2", status: "pending") }
        @ti_d = as(@user) { create(:tag_alias, antecedent_name: "ti_a3", consequent_name: "ti_c3", status: "deleted") }
      end

      should "allow creator while pending" do
        assert_equal(true, @user.can?(:destroy, @ti_p))
        assert_equal(false, @user.can?(:destroy, @ti_o))
        assert_equal(true, @other_user.can?(:destroy, @ti_o))
        assert_equal(false, @other_user.can?(:destroy, @ti_p))
      end

      should "not allow creator when active" do
        assert_equal(false, @user.can?(:destroy, @ti_a))
      end

      should "not allow when already deleted" do
        assert_equal(false, @admin.can?(:destroy, @ti_d))
        assert_equal(false, @user.can?(:destroy, @ti_d))
      end

      should "allow admins" do
        assert_equal(true, @admin.can?(:destroy, @ti_p))
        assert_equal(true, @admin.can?(:destroy, @ti_a))
      end

      should "allow bureaucrats" do
        assert_equal(true, @bureaucrat.can?(:destroy, @ti_p))
        assert_equal(true, @bureaucrat.can?(:destroy, @ti_a))
      end

      should "not allow mods" do
        assert_equal(false, @mod.can?(:destroy, @ti_p))
      end
    end

    # TODO: Test when status is retired, processing, & queued
    context "#editable_by?" do
      setup do
        @other_user = create(:user)
        @other_user.init_ability
        @ti_p = as(@user) { create(:tag_alias, antecedent_name: "ti_a0", consequent_name: "ti_c0", status: "pending") }
        @ti_a = as(@user) { create(:tag_alias, antecedent_name: "ti_a1", consequent_name: "ti_c1", status: "active") }
        @ti_o = as(@other_user) { create(:tag_alias, antecedent_name: "ti_a2", consequent_name: "ti_c2", status: "pending") }
        @ti_d = as(@user) { create(:tag_alias, antecedent_name: "ti_a3", consequent_name: "ti_c3", status: "deleted") }
      end

      should "not allow creator" do
        assert_equal(false, @user.can?(:update, @ti_p))
        assert_equal(false, @other_user.can?(:update, @ti_o))
      end

      should "not allow when not pending" do
        assert_equal(false, @admin.can?(:update, @ti_d))
        assert_equal(false, @bureaucrat.can?(:update, @ti_d))
        assert_equal(false, @user.can?(:update, @ti_d))
        assert_equal(false, @admin.can?(:update, @ti_a))
        assert_equal(false, @bureaucrat.can?(:update, @ti_a))
        assert_equal(false, @user.can?(:update, @ti_a))
      end

      should "allow admins" do
        assert_equal(true, @admin.can?(:update, @ti_p))
        assert_equal(true, @admin.can?(:update, @ti_o))
      end

      should "allow bureaucrats" do
        assert_equal(true, @bureaucrat.can?(:update, @ti_p))
        assert_equal(true, @bureaucrat.can?(:update, @ti_o))
      end

      should "not allow mods" do
        assert_equal(false, @mod.can?(:update, @ti_p))
      end
    end
  end
end

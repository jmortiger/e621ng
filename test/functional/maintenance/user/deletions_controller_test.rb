# frozen_string_literal: true

require "test_helper"

module Maintenance
  module User
    class DeletionsControllerTest < ActionDispatch::IntegrationTest
      context "in all cases" do
        setup do
          @user = create(:user, created_at: 2.weeks.ago)
        end

        context "#show" do
          should "render" do
            get_auth maintenance_user_deletion_path, @user
            assert_response :success
          end
        end

        context "#destroy" do
          should "render" do
            delete_auth maintenance_user_deletion_path, @user, params: { password: "6cQE!wbA" }
            assert_redirected_to(posts_path)
          end
        end
      end
    end
  end
end

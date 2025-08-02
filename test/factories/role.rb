# frozen_string_literal: true

FactoryBot.define do
  factory(:role) do
    sequence(:name) { |n| "role_name_#{n}" }
    parent_role { nil }
    direct_permissions { 0 }
    user { create(:user, created_at: 2.weeks.ago) }
    # updated_at { Time.now }
    # created_at { Time.now }

    # factory(:artist_tag) do
    #   category { Tag.categories.artist }
    # end

    # factory(:copyright_tag) do
    #   category { Tag.categories.copyright }
    # end

    # factory(:character_tag) do
    #   category { Tag.categories.character }
    # end
  end
end

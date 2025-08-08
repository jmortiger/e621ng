# frozen_string_literal: true

module RolesModule
  RESOURCES = %w[
    posts
    users
    comments
    votes
    forum_topics
    forum_posts
    aliases
    implications
    burs
    staff_notes
  ].freeze
  # TODO: Former staff
  # TODO: undo_post_versions
  # TODO: this https://github.com/e621ng/e621ng/blob/a1c52f7fa5fd47565c490f7c02196670ae617f44/app/views/post_versions/_secondary_links.html.erb#L10-L11
  # TODO: wat https://github.com/e621ng/e621ng/blob/a1c52f7fa5fd47565c490f7c02196670ae617f44/app/views/posts/partials/show/content/_edit.html.erb#L48
  # Privileged
  # Janitor
  # Moderator
  # Admin
  # Misc
  PERMISSIONS = %w[
    lock_rating
    parent_wiki
    color_dtext
    bypass_general_throttle
    undo_post_versions
    use_tag_scripts

    delete_posts
    see_deleted_posts
    lock_posts
    create_staff_notes
    view_staff_notes
    see_deleted_feedbacks

    see_tickets
    claim_tickets
    see_votes
    ban
    hide_comments
    lock_comments

    is_bd_staff
    see_ips
    approve_AIBURs
    skip_forum
    destroy
    lock_tags
    edit_users
    lock_wikis
    hide_posts

    upload_free
    replacements_beta
  ].freeze

  IMPLICATIONS = {
    lock_rating:
  }.freeze

  include Danbooru::HasBitFlags

  define_static_bit_field_methods :permissions
  class Archetype
    attr_accessor :name, :display_name, :permissions, :parent

    has_bit_flags :permissions, skip_statics: true

    def initialize(name, permissions, parent: nil, display_name: nil)
      @name = name.to_s.downcase
      @display_name = display_name || name
      @permissions = permissions.is_a?(Numeric) ? permissions : calculate_permissions_value(permissions)
      @parent = parent
    end
  end

  ARCHETYPES = {
    member: Archetype.new("Member", %w[]),
    admin: Archetype.new("Admin", %w[
      is_bd_staff
      see_ips
      approve_AIBURs
      skip_forum
      destroy
      lock_tags
      edit_users
      lock_wikis
      hide_posts
    ]),
    bd_staff: Archetype.new("BD Staff", PERMISSIONS),
  }.freeze

  # Can have multiple archetypes
  module RoleInstance
    def initialize(archetype, direct_permissions)
      @archetype = archetype
      @direct_permissions = direct_permissions
    end
  end
end

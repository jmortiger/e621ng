# frozen_string_literal: true

class Role < ApplicationRecord
  # TODO: Former staff
  # TODO: can_undo_post_versions
  # TODO: this https://github.com/e621ng/e621ng/blob/a1c52f7fa5fd47565c490f7c02196670ae617f44/app/views/post_versions/_secondary_links.html.erb#L10-L11
  # TODO: wat https://github.com/e621ng/e621ng/blob/a1c52f7fa5fd47565c490f7c02196670ae617f44/app/views/posts/partials/show/content/_edit.html.erb#L48
  # Privileged
  # Janitor
  # Moderator
  # Admin
  # Misc
  PERMISSIONS = %w[
    can_lock_rating
    can_parent_wiki
    can_color_dtext
    can_bypass_general_throttle
    can_undo_post_versions
    can_use_tag_scripts

    can_delete_posts
    can_see_deleted_posts
    can_lock_posts
    can_create_staff_notes
    can_view_staff_notes
    can_see_deleted_feedbacks

    can_see_tickets
    can_claim_tickets
    can_see_votes
    can_ban
    can_hide_comments
    can_lock_comments

    is_bd_staff
    can_see_ips
    can_approve_AIBURs
    can_skip_forum
    can_destroy
    can_lock_tags
    can_edit_users
    can_lock_wikis
    can_hide_posts

    can_upload_free
    replacements_beta
  ].freeze

  class Archetype
    attr_accessor :name, :display_name, :permissions, :parent_role

    # def initialize(name:, permissions:, parent_role:, display_name: nil)
    def initialize(name, permissions, parent_role: nil, display_name: nil)
      @name = name
      @display_name = display_name || name
      @permissions = permissions
      @parent_role = parent_role
    end
  end

  ARCHETYPES = {
    admin: Archetype.new("Admin", %w[
      is_bd_staff
      can_see_ips
      can_approve_AIBURs
      can_skip_forum
      can_destroy
      can_lock_tags
      can_edit_users
      can_lock_wikis
      can_hide_posts
    ]),
  }.freeze

  include Danbooru::HasBitFlags
  # has_bit_flags PERMISSIONS, field: "direct_permissions", active_names: true, calculate_bit_flags: true
  has_bit_flags PERMISSIONS, field: "inherited_permissions", readonly: true, active_names: true, calculate_bit_flags: true
  # has_bit_flags PERMISSIONS, field: "permissions", composed: { field: "permissions", xor: "direct_permissions" }, active_names: true, calculate_bit_flags: true
  has_bit_flags PERMISSIONS, composed: { main: "direct_permissions", xor: "inherited_permissions" }, active_names: true, calculate_bit_flags: true
  belongs_to :user

  def inherited_permissions
    t = ARCHETYPES[parent_role.downcase.to_sym].permissions
    @inherited_permissions ||= Role.calculate_direct_permissions_value(t)
  end

  # The composed permissions
  # def permissions
  #   return @permissions unless @permissions.nil?
  #   return (@permissions = direct_permissions) if parent_role.nil?
  #   @permissions = direct_permissions
  #   if SETTINGS[:uses_chain]
  #     raise NotImplementedError
  #   elsif SETTINGS[:inverted_flag_name] && parent_role.permissions.include?(SETTINGS[:inverted_flag_name])
  #     raise NotImplementedError
  #   else
  #     # self.active_permissions |= ARCHETYPES[parent_role.to_sym].permissions
  #     @permissions |= Role.calculate_permissions_value(ARCHETYPES[parent_role.to_sym].permissions)
  #   end
  # end

  attr_writer :inherited_permissions
end

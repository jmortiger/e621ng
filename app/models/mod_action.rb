class ModAction < ApplicationRecord
  belongs_to :creator, :class_name => "User"
  before_validation :initialize_creator, :on => :create
  validates :creator_id, presence: true

  serialize :values_old

  #####DIVISIONS#####
  #Groups:     0-999
  #Individual: 1000-1999
  #####Actions#####
  #Create:   0
  #Update:   1
  #Delete:   2
  #Undelete: 3
  #Ban:      4
  #Unban:    5
  #Misc:     6-19
  enum category: {
      user_delete: 2,
      user_ban: 4,
      user_unban: 5,
      user_name_change: 6,
      user_level_change: 7,
      user_approval_privilege: 8,
      user_upload_privilege: 9,
      user_account_upgrade: 19,
      user_feedback_update: 21,
      user_feedback_delete: 22,
      post_delete: 42,
      post_undelete: 43,
      post_ban: 44,
      post_unban: 45,
      post_permanent_delete: 46,
      post_move_favorites: 47,
      pool_delete: 62,
      pool_undelete: 63,
      artist_ban: 184,
      artist_unban: 185,
      comment_update: 81,
      comment_delete: 82,
      forum_topic_delete: 202,
      forum_topic_undelete: 203,
      forum_topic_lock: 206,
      forum_post_update: 101,
      forum_post_delete: 102,
      tag_alias_create: 120,
      tag_alias_update: 121,
      tag_implication_create: 140,
      tag_implication_update: 141,
      ip_ban_create: 160,
      ip_ban_delete: 162,
      mass_update: 1000,
      bulk_revert: 1001,
      other: 2000
  }

  KnownActions = [
      :artist_ban,
      :artist_unban,
      :blip_delete,
      :blip_hide,
      :blip_unhide,
      :blip_update,
      :comment_delete,
      :comment_hide,
      :comment_unhide,
      :comment_update,
      :forum_category_create,
      :forum_category_delete,
      :forum_category_update,
      :forum_post_delete,
      :forum_post_hide,
      :forum_post_unhide,
      :forum_post_update,
      :forum_topic_delete,
      :forum_topic_hide,
      :forum_topic_unhide,
      :forum_topic_lock,
      :forum_topic_unlock,
      :forum_topic_update,
      :help_create,
      :help_delete,
      :help_update,
      :ip_ban_create,
      :ip_ban_delete,
      :pool_delete,
      :pool_undelete,
      :post_move_favorites,
      :post_destroy,
      :post_delete,
      :post_undelete,
      :post_rating_lock,
      :report_reason_create,
      :report_reason_delete,
      :report_reason_update,
      :set_update,
      :set_delete,
      :set_mark_private,
      :tag_alias_create,
      :tag_alias_update,
      :tag_implication_create,
      :tag_implication_update,
      :ticket_claim,
      :ticket_unclaim,
      :ticket_update,
      :user_blacklist_changed,
      :user_flags_change,
      :user_level_change,
      :user_name_change,
      :user_delete,
      :user_ban,
      :user_unban,
      :user_feedback_create,
      :user_feedback_update,
      :user_feedback_delete,
      :wiki_page_rename,
      :wiki_page_delete,
      :wiki_page_lock,

      :mass_update,

      :takedown_process
  ]

  def self.search(params)
    q = super

    if params[:creator_id].present?
      q = q.where("creator_id = ?", params[:creator_id].to_i)
    end

    if params[:creator_name].present?
      q = q.where("creator_id = (select _.id from users _ where lower(_.name) = ?)", params[:creator_name].mb_chars.downcase)
    end

    if params[:action].present?
      q = q.where('action = ?', params[:action])
    end

    q.apply_default_order(params)
  end


  def category_id
    self.class.categories[category]
  end

  def method_attributes
    super + [:category_id]
  end

  def hidden_attributes
    super + [:values]
  end

  def self.log(cat = :other, details = {})
    create(category: categories.fetch(cat, 2000), action: cat.to_s, values: details)
  end

  def initialize_creator
    self.creator_id = CurrentUser.id
  end
end

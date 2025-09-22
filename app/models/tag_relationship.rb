# frozen_string_literal: true

class TagRelationship < ApplicationRecord
  self.abstract_class = true

  SUPPORT_HARD_CODED = true

  belongs_to_creator
  belongs_to :approver, class_name: "User", optional: true
  belongs_to :forum_post, optional: true
  belongs_to :forum_topic, optional: true
  belongs_to :antecedent_tag, class_name: "Tag", foreign_key: "antecedent_name", primary_key: "name", default: -> { Tag.find_or_create_by_name(antecedent_name) }
  belongs_to :consequent_tag, class_name: "Tag", foreign_key: "consequent_name", primary_key: "name", default: -> { Tag.find_or_create_by_name(consequent_name) }

  scope :active, -> { approved }
  scope :approved, -> { where(status: %w[active processing queued]) }
  scope :deleted, -> { where(status: "deleted") }
  scope :pending, -> { where(status: "pending") }
  scope :retired, -> { where(status: "retired") }
  scope :duplicate_relevant, -> { where(status: %w[active processing queued pending]) }

  before_validation :initialize_creator, on: :create
  before_validation :normalize_names
  validates :status, format: { with: /\A(active|deleted|pending|processing|queued|retired|error: .*)\Z/ }
  validates :creator_id, :antecedent_name, :consequent_name, presence: true
  validates :creator, presence: { message: "must exist" }, if: -> { creator_id.present? }
  validates :approver, presence: { message: "must exist" }, if: -> { approver_id.present? }
  validates :forum_topic, presence: { message: "must exist" }, if: -> { forum_topic_id.present? }
  validate :validate_creator_is_not_limited, on: :create
  validates :antecedent_name, tag_name: { disable_ascii_check: true }, if: :antecedent_name_changed?
  validates :consequent_name, tag_name: true, if: :consequent_name_changed?
  validate :antecedent_and_consequent_are_different

  scope :dnp_artist_consequent, -> { joins(consequent_tag: { artist: :avoid_posting }).where(avoid_postings_artists: { is_active: true }) }
  scope :dnp_artist_antecedent, -> { joins(antecedent_tag: { artist: :avoid_posting }).where(avoid_postings_artists: { is_active: true }) }
  scope :dnp_artist, -> { left_joins(consequent_tag: { artist: :avoid_posting }, antecedent_tag: { artist: :avoid_posting }).where(avoid_postings_artists: { is_active: true }) }
  scope :no_dnp_artist, -> {
    tr = left_joins(consequent_tag: { artist: :avoid_posting }, antecedent_tag: { artist: :avoid_posting })
    tr.where.not(consequent_tag: { artists: { avoid_posting: true } })
      .and(tr.where.not(antecedent_tag: { artists: { avoid_posting: true } }))
  }

  def initialize_creator
    self.creator_id = CurrentUser.user.id
    self.creator_ip_addr = CurrentUser.ip_addr
  end

  def normalize_names
    self.antecedent_name = antecedent_name.downcase.tr(" ", "_")
    self.consequent_name = consequent_name.downcase.tr(" ", "_")
  end

  def validate_creator_is_not_limited
    allowed = creator.can_suggest_tag_with_reason
    if allowed != true
      errors.add(:creator, User.throttle_reason(allowed))
      return false
    end
    true
  end

  def is_approved?
    status.in?(%w[active processing queued])
  end

  %w[retired deleted pending active].each do |s|
    define_method :"is_#{s}?" do
      status == s
    end
  end

  def is_errored?
    status =~ /\Aerror:/
  end

  # TODO: Redirect to CanCanCan ability
  def can_manage_aiburs(user)
    user.is_admin? || user.is_bureaucrat?
  end

  # * Pending
  # * User is an admin
  # * Either isn't aliasing to/from DNP or is a BD staff member
  def approvable_by?(user)
    is_pending? && can_manage_aiburs(user) && (user.is_bd_staff? || !(consequent_tag&.artist&.is_dnp? || antecedent_tag&.artist&.is_dnp?))
  end

  # A scope that returns the entries approvable by the given user; i.e:
  # * Pending
  # * User is an admin/bureaucrat
  # * Either isn't aliasing to/from DNP or is a BD staff member
  # NOTE: Needs to return a relation of none or return the default scope.
  scope :approvable_by, ->(user) {
    if can_manage_aiburs(user)
      (user.is_bd_staff? ? pending : pending.left_joins(consequent_tag: { artist: :avoid_posting }, antecedent_tag: { artist: :avoid_posting }).and(no_dnp_artist))
    else
      TagRelationship.none
    end
  }

  # Either an admin deleting a non-deleted relationship OR the creator deleting a pending relationship.
  def deletable_by?(user)
    (can_manage_aiburs(user) && !is_deleted?) || (is_pending? && creator.id == user.id)
  end

  # A scope that returns the entries deletable by the given user (i.e. for admins/bureaucrats, all pending, otherwise none).
  # NOTE: Needs to return a relation of none or return the default scope.
  scope :deletable_by, ->(user) { can_manage_aiburs(user) ? where.not(status: "deleted") : where(creator_id: user.id, status: "pending") }

  # All of the entries editable by the given user (i.e. for admins/bureaucrats, all pending, otherwise none).
  # TODO: Should the creator be able to change this?
  def editable_by?(user)
    is_pending? && can_manage_aiburs(user)
  end

  # A scope that returns the entries editable by the given user (i.e. for admins/bureaucrats, all pending, otherwise none).
  # NOTE: Needs to return a relation of none or return the default scope.
  scope :editable_by, ->(user) { can_manage_aiburs(user) ? pending : TagRelationship.none }

  module SearchMethods
    def name_matches(name)
      where("(antecedent_name like ? escape E'\\\\' or consequent_name like ? escape E'\\\\')", name.downcase.to_escaped_for_sql_like, name.downcase.to_escaped_for_sql_like)
    end

    def status_matches(status)
      status = status.downcase

      if status == "approved"
        where(status: %w[active processing queued])
      else
        where(status: status)
      end
    end

    def for_creator(id)
      where("creator_id = ?", id)
    end

    def pending_first
      # unknown statuses return null and are sorted first
      order(Arel.sql("array_position(array['queued', 'processing', 'pending', 'active', 'deleted', 'retired'], status::text) NULLS FIRST, #{table_name}.id desc"))
    end

    # FIXME: Rails assigns different join aliases for joins(:antecedent_tag) and joins(:antecedent_tag, :consequent_tag)
    # This makes it impossible to use when ordering, at least from what I can tell.
    # There must be a different solution for this.
    def join_antecedent
      joins("LEFT OUTER JOIN tags antecedent_tag on antecedent_tag.name = antecedent_name")
    end

    def join_consequent
      joins("LEFT OUTER JOIN tags consequent_tag on consequent_tag.name = consequent_name")
    end

    def left_joins_avoid_postings_artist(relation = nil)
      # relation&.left_joins(consequent_tag: { artist: :avoid_posting }, antecedent_tag: { artist: :avoid_posting }) || left_joins(consequent_tag: { artist: :avoid_posting }, antecedent_tag: { artist: :avoid_posting })
      (relation || self).left_joins(consequent_tag: { artist: :avoid_posting }, antecedent_tag: { artist: :avoid_posting })
    end

    def default_order
      pending_first
    end

    def search(params)
      q = super

      if params[:name_matches].present?
        q = q.name_matches(params[:name_matches])
      end

      if params[:antecedent_name].present?
        # Split at both space and , to preserve backwards compatibility
        q = q.where(antecedent_name: params[:antecedent_name].split(/[ ,]/).first(100))
      end

      if params[:consequent_name].present?
        q = q.where(consequent_name: params[:consequent_name].split(/[ ,]/).first(100))
      end

      if params[:status].present?
        q = q.status_matches(params[:status])
      end

      if params[:antecedent_tag_category].present?
        q = q.join_antecedent.where("antecedent_tag.category": params[:antecedent_tag_category].split(",").first(100))
      end

      if params[:consequent_tag_category].present?
        q = q.join_consequent.where("consequent_tag.category": params[:consequent_tag_category].split(",").first(100))
      end

      q = q.where_user(:creator_id, :creator, params)
      q = q.where_user(:approver_id, :approver, params)

      case params[:order]
      when "created_at"
        q = q.order("#{table_name}.created_at desc nulls last, #{table_name}.id desc")
      when "updated_at"
        q = q.order("#{table_name}.updated_at desc nulls last, #{table_name}.id desc")
      when "name"
        q = q.order("antecedent_name asc, consequent_name asc")
      when "tag_count"
        q = q.join_consequent.order("consequent_tag.post_count desc, antecedent_name asc, consequent_name asc")
      else
        q = q.apply_basic_order(params)
      end

      q
    end
  end

  module MessageMethods
    def relationship
      # "TagAlias" -> "tag alias", "TagImplication" -> "tag implication"
      self.class.name.underscore.tr("_", " ")
    end

    def approval_message(approver)
      "The #{relationship} [[#{antecedent_name}]] -> [[#{consequent_name}]] #{forum_link} has been approved by @#{approver.name}."
    end

    def failure_message(error = nil)
      "The #{relationship} [[#{antecedent_name}]] -> [[#{consequent_name}]] #{forum_link} failed during processing. Reason: #{error}"
    end

    def reject_message(rejector)
      "The #{relationship} [[#{antecedent_name}]] -> [[#{consequent_name}]] #{forum_link} has been rejected by @#{rejector.name}."
    end

    def retirement_message
      "The #{relationship} [[#{antecedent_name}]] -> [[#{consequent_name}]] #{forum_link} has been retired."
    end

    def forum_link
      "(forum ##{forum_post.id})" if forum_post.present?
    end
  end

  concerning :EmbeddedText do
    class_methods do
      def embedded_pattern
        raise NotImplementedError
      end
    end
  end

  def antecedent_and_consequent_are_different
    if antecedent_name == consequent_name
      errors.add(:base, "Cannot alias or implicate a tag to itself")
    end
  end

  def estimate_update_count
    Post.fast_count(antecedent_name)
  end

  def update_posts
    Post.without_timeout do
      Post.sql_raw_tag_match(antecedent_name).find_each do |post|
        post.with_lock do
          CurrentUser.scoped(creator, creator_ip_addr) do
            post.do_not_version_changes = true
            post.tag_string += " "
            post.save!
          end
        end
      end
    end
  end

  extend SearchMethods
  include MessageMethods
end

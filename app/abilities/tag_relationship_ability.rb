# frozen_string_literal: true

class TagRelationshipAbility < ApplicationAbility
  # include CanCan::Ability
  def self.owner_key
    "creator"
  end

  # Must define `klass` in derivatives.

  def initialize(user)
    super(user) # @user = user

    # Define abilities for the user here. For example:
    #
    #   return unless user.present?
    #   can :read, :all
    #   return unless user.admin?
    #   can :manage, :all
    #
    # The first argument to `can` is the action you are giving the user
    # permission to do.
    # If you pass :manage it will apply to every action. Other common actions
    # here are :read, :create, :update and :destroy.
    #
    # The second argument is the resource the user can perform the action on.
    # If you pass :all it will apply to every resource. Otherwise pass a Ruby
    # class of the resource.
    #
    # The third argument is an optional hash of conditions to further filter the
    # objects.
    # For example, here the user can only update published articles.
    #
    #   can :update, Article, published: true
    #
    # See the wiki for details:
    # https://github.com/CanCanCommunity/cancancan/blob/develop/docs/define_check_abilities.md

    # Everyone can see them
    can :read, klass

    # Must be logged in...
    return if user.blank? || user.is_anonymous? || user.is_blocked?

    # ...to make.
    can :create, klass

    # # Must be the creator, an aibureaucrat, or an admin...
    # return unless user.blank? || user.is_anonymous? || user.is_blocked?

    # TODO: Should you be able to update your own if they are pending?

    # ...to reject your own unapproved relationships.
    # can(:destroy, klass, klass.deletable_by(user)) { |rel| rel.deletable_by?(user) }
    # can(:reject, klass, klass.deletable_by(user)) { |rel| rel.deletable_by?(user) }
    can :destroy, klass, status: "pending", creator_id: user.id
    can :reject, klass, status: "pending", creator_id: user.id

    # Must be an aibureaucrat or an admin...
    return unless user.is_admin? || user.is_bureaucrat?
    # ...to edit pending relationships.
    # can(:update, klass, klass.editable_by(user)) { |rel| rel.editable_by?(user) }
    can :update, klass, status: "pending" if klass.can_manage_aiburs?(user)

    # ...to delete everything but already deleted ones.
    # TODO: Should admins be able to delete DNP relationships? They can't make them.
    can :destroy, klass
    can :reject, klass
    cannot :destroy, klass, status: "deleted"
    cannot :reject, klass, status: "deleted"

    # ...to approve all pending relationships but DNP relationships.
    can(:approve, klass, klass.approvable_by(user)) { |rel| rel.approvable_by?(user) }
  end
end

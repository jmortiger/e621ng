# frozen_string_literal: true

class ApplicationAbility
  include CanCan::Ability

  # self.abstract_class = true

  attr_reader :user

  def initialize(user)
    @user = user
  end

  # The class for which this is modelling the abilities for.
  def self.klass
    raise NotImplementedError "ApplicationAbility.klass must be defined on deriving classes."
  end

  def klass
    self.class.klass
  end

  def self.owner_key
    "user"
  end

  def self.owner_id_key
    "#{owner_key}_id"
  end

  def is_owner?(resource)
    resource.send(owner_id_key) == user.id
  end

  # A `Relation` for all the records of the modeled resource owned by the user.
  def owned
    klass.where(owner_id_key => user.id)
  end
end

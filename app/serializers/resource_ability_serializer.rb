# frozen_string_literal: true

class ResourceAbilitySerializer < ActiveModel::Serializer
  attributes :id, :active_permissions, :active_restrictions
end

# frozen_string_literal: true

# docker compose run --rm rails_dev generate model Role name:string parent_role:string direct_permissions:bigint user:belongs_to
class CreateRoles < ActiveRecord::Migration[7.1]
  def change
    create_table :roles do |t|
      t.string :name
      t.string :parent_role
      t.bigint :direct_permissions
      # t.bigint :direct_permissions, default: 0, null: false
      t.belongs_to :user

      t.timestamps
    end
  end
end

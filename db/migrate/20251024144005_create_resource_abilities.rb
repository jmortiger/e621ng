class CreateResourceAbilities < ActiveRecord::Migration[7.2]
  def change
    create_table :resource_abilities do |t|
      t.bigint :active_permissions
      t.bigint :active_restrictions

      t.timestamps
    end
  end
end

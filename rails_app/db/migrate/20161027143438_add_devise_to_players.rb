class AddDeviseToPlayers < ActiveRecord::Migration[5.0]
  def self.up
    create_table :players, options: "ROW_FORMAT=DYNAMIC"  do |t|
      ## Omniauthable
      t.string :provider, null: false
      t.string :uid, null: false
      t.string :access_token, null: false

      ## Rememberable
      t.datetime :remember_created_at
      t.string :remember_token

      ## Trackable
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip
    end

    add_index :players, [:provider, :uid], unique: true
  end

  def self.down
    # By default, we don't want to make any assumption about how to roll back a migration when your
    # model already existed. Please edit below which fields you would like to remove in this migration.
    raise ActiveRecord::IrreversibleMigration
  end
end

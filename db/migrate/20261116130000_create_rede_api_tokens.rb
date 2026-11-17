class CreateRedeApiTokens < ActiveRecord::Migration[7.1]
  def change
    create_table :rede_api_tokens do |t|
      t.references :account, null: false, foreign_key: true
      t.references :created_by_user, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :name, null: false
      t.string :token_digest, null: false
      t.string :token_prefix, null: false
      t.string :scopes, array: true, null: false, default: ['projects:read']
      t.datetime :last_used_at
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :rede_api_tokens, :token_digest, unique: true
  end
end

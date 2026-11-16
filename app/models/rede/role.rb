# == Schema Information
#
# Table name: rede_roles
#
#  id         :bigint           not null, primary key
#  key        :string           not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_rede_roles_on_account_id          (account_id)
#  index_rede_roles_on_account_id_and_key  (account_id,key) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Rede::Role < ApplicationRecord
  belongs_to :account
  has_many :assignments, class_name: 'Rede::Assignment', dependent: :restrict_with_error, inverse_of: :role

  validates :key, :name, presence: true
  validates :key, uniqueness: { scope: :account_id }

  before_validation do
    self.key = key.strip if key
    self.name = name.strip if name
  end
end

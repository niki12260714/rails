class Purchase < ApplicationRecord
  belongs_to :item
  belongs_to :group
  belongs_to :user, foreign_key: 'purchase_user_id', inverse_of: :primary_members, optional: true
  has_many :purchase_members
  
  #買出し担当が引数のユーザーかつ購入ステータスが未購入のスコープ(shopping_controllerで使用)
  scope :get_own_charge, ->(uid){
    where(purchase_user_id: uid, item_purchase_status: 0)
  }
  
end

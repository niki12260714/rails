class PurchaseMember < ApplicationRecord
  belongs_to :item
  belongs_to :group, optional: true
  belongs_to :user
  belongs_to :purchase, optional: true
  
  scope :get_members_list , ->(uid){
    where(user_id: uid)
  }
  
end

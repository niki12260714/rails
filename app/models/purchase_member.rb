class PurchaseMember < ApplicationRecord
  belongs_to :item
  belongs_to :group, optional: true
  belongs_to :user
  belongs_to :purchase, optional: true
  
end

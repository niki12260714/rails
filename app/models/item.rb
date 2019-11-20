class Item < ApplicationRecord
  has_many :purchase_members, dependent: :destroy
  has_many :purchases, dependent: :destroy
  has_many :groups, through: :purchases
  has_many :groups, through: :purchase_members
  has_many :users, through: :purchase_members
  
  #個人用のアイテム取得(items_controller)
  scope :get_personal_item, -> (uid){ 
    select("items.id as id, items.item_name, items.circle_name, items.item_memo, items.item_label, items.item_url, items.novelty_flg").\
    joins(:purchase_members).\
    where("purchase_members.group_id is null AND purchase_members.user_id = ?", uid).\
    distinct
  }

  
end

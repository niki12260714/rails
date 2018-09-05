class Plan
  include ActiveModel::Model
  attr_accessor :item_name, :circle_name, :space_number, :price, :novelty_flg, :item_memo, :purchase_user_id, :priority, :want_count, :group_id, :mode, :cr, :ac, :item_id, :block_number
  
  validates :item_name,
    presence: true,
    length: {maximum: 100}
  
  validates :circle_name,
    length: {maximum: 30}
  
  validates :space_number,
    length: {maximum: 30}
  
  validates :price,
    numericality: {allow_blank: true, only_integer: true}
  
  validates :item_memo,
    length: {maximum: 100}
  
  validates :block_number,
    length: {maximum: 1}
  
end
class ItemAdd
  include ActiveModel::Model
  attr_accessor :item_name, :circle_name, :personal_memo
  
  validates :item_name,
    presence: true,
    length: {maximum: 100}
  
  validates :circle_name,
    length: {maximum: 30}
  
  validates :personal_memo,
    length: {maximum: 100}
end
class PersonalItem
  include ActiveModel::Model
  attr_accessor :item_name, :circle_name, :price, :novelty_flg, :item_memo, :want_count, :mode, :item_id
  
  validates :item_name,
    presence: true,
    length: {maximum: 100}
  
  validates :circle_name,
    length: {maximum: 30}
  
  validates :price,
    numericality: {allow_blank: true, only_integer: true}
  
  validates :item_memo,
    length: {maximum: 100}
  
  validates :want_count,
    numericality: {allow_blank: false, only_integer: true, greater_than_or_equal_to: 1}
  
end
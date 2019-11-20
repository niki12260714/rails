class PersonalItem
  include ActiveModel::Model
  attr_accessor :item_name, :circle_name, :price, :novelty_flg, :item_memo, :want_count, :mode, :item_id, :cotinue_flg, :cotinue_circle_flg, :item_label, :item_url
  
  validates :item_name,
    presence: true,
    length: {maximum: 100}
  
  validates :circle_name,
    length: {maximum: 30, allow_blank:true}
  
  validates :price,
    numericality: {allow_blank: true, only_integer: true}
  
  validates :item_memo,
    length: {maximum: 200, allow_blank: true}
  
  validates :item_url,
    length: {maximum: 150, allow_blank: true},
    format: {with: /\A#{URI::regexp(%w(http https))}\z/, allow_blank: true}
  
  validates :want_count,
    numericality: {allow_blank: false, only_integer: true, greater_than_or_equal_to: 1}
  
end
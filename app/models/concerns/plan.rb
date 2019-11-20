class Plan
  include ActiveModel::Model
  attr_accessor :item_name, :circle_name, :space_number, :price, :novelty_flg, :item_memo, :purchase_user_id, :priority, :want_count,\
                :group_id, :mode, :cr, :ac, :item_id, :block_number, :cotinue_flg, :cotinue_circle_flg, :item_label, :item_url
  
  validates :item_name,
    presence: true,
    length: {maximum: 100}
  
  validates :circle_name,
    length: {maximum: 30, allow_blank: true}
  
  validates :space_number,
    length: {maximum: 30, allow_blank: true}
  
  validates :price,
    numericality: {allow_blank: true, only_integer: true}
  
  validates :item_memo,
    length: {maximum: 200, allow_blank: true}
  
  validates :item_url,
    length: {maximum: 150, allow_blank: true},
    format: {with: /\A#{URI::regexp(%w(http https))}\z/, allow_blank: true}
  
  validates :block_number,
    length: {maximum: 1}
  
end
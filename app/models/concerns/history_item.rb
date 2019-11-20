class HistoryItem
  include ActiveModel::Model
  attr_accessor :item_name, :count, :price, :novelty_flg, :p_id
  
  #HistoryListの中にいれるアイテムのモデル
end
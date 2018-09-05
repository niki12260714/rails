class HistoryItem
  include ActiveModel::Model
  attr_accessor :item_name, :count, :price, :novelty_flg
  
  #HistoryListの中にいれるアイテムのモデル
end
class HistoryList
  include ActiveModel::Model
  attr_accessor :pass_item, :pass_bad_item, :receive_item, :receive_bad_item, :target_user, :pass_item_price, :receive_item_price
  
  #買出し履歴のマトリクス表示のためのモデル
  #pass_item：自分が渡すアイテムの一覧（買えたもの、want_countが1以上のもの）
  #pass_bad_item：渡すはずが買えなかったアイテム一覧（want_countが0のもの）
  #receive_item：受け取るアイテム一覧（買えたもの、want_countが1以上のもの）
  #receive_bad_item：受け取れないアイテム一覧（want_countが0のもの）
  #target_user：対象ユーザー名
  #pass_item_price：pass_itemの金額合計
  #receive_item_price：receive_itemの金額合計
end
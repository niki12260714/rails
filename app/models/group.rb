class Group < ApplicationRecord
  has_many :group_members, dependent: :destroy, inverse_of: :group
  has_many :group_logs, dependent: :destroy
  has_many :purchases, dependent: :destroy
  has_many :purchase_members
  has_many :users, through: :purchase_members
  has_many :users, through: :group_members
  has_many :items, through: :purchase_members
  has_many :items, through: :purchases
  belongs_to :user, foreign_key: 'create_user_id', inverse_of: :create_user, optional: true

  #引数のユーザーが所属するグループかつ、そのグループの買出し日が今日より先の日付であるものを抽出(item_controller,group_controllerで使用)
  scope :get_group_list_future, ->(uid){
    joins(:group_members).\
    where("date(CONVERT_TZ(groups.purchase_day,'UTC','Asia/Tokyo')) >= ? AND group_members.user_id = ? AND group_members.join_status = true AND groups.end_flg = false", Date.today, uid)
  }
  
  #引数のユーザーが所属するグループかつ、そのグループの買出し日が今日であるものを抽出(buy.rbとsp_controllerで使用,end_flgは見てない、当日分は全てイベント当日で見る)
  scope :get_group_list_today, ->(uid){
    joins(:group_members).where("date(CONVERT_TZ(groups.purchase_day,'UTC','Asia/Tokyo')) = ? AND group_members.user_id = ? AND group_members.join_status = true", Date.today, uid)
  }
  
  #引数のユーザーが所属するグループ(招待を承認している)を抽出(history_controllerで使用)
  scope :get_group_list_all, ->(uid){
    joins(:group_members).\
    where("group_members.user_id = ? AND group_members.join_status = true", uid)
  }
  
  #買出し日が本日のスコープ
  scope :get_today_group, ->{
    where("end_flg = false and date(CONVERT_TZ(purchase_day,'UTC','Asia/Tokyo')) = ?", Date.today)
  }
  
  #買出し日が未来のスコープ
  scope :get_future_group, ->{
    where("end_flg = false and date(CONVERT_TZ(purchase_day,'UTC','Asia/Tokyo')) >= ?", Date.today)
  }
  
  #引数のID
  scope :get_group_by_id, ->(gid){
    where(id: gid)
  }
end

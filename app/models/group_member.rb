class GroupMember < ApplicationRecord
  belongs_to :user, inverse_of: :group_members
  belongs_to :group, inverse_of: :group_members
  
  #グループIDを元にusersテーブルまで紐づけてグループメンバーの情報を取得する(plan_controller,history_controllerで使用)
  scope :get_group_member, ->(gid){
    select(:id, :user_id, :join_status, :system_id, :nickname, :provider, :twitter_acount).\
    joins(:user).\
    where(group_id: gid)
  }
  
  #ユーザーIDを元にusersテーブルまで紐づけてグループメンバーの情報を取得する(plan_controllerで使用)
  scope :get_member_info, -> (uid){ 
    select(:id, :user_id, :join_status, :system_id, :nickname).\
    joins(:user).\
    where(user_id: uid)
  }
  
  #ユーザーIDを元にデータを絞り込む（結びつけは行わない、history_controllerで使用）
  scope :get_member, -> (uid){
    where(user_id: uid, join_status: true)
  }
  
end

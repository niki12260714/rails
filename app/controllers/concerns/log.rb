module Log
  extend ActiveSupport::Concern
  
  included do
    #before_action :check_logined
  end
  
  #グループを新規に作成した時のログ文章作成
  def create_group_log(g_name,user_name)
    "【#{user_name}】さんが新規にグループ名【#{g_name}】を作成しました"
  end
  
  #グループを新規に作成した時のログ文章作成
  def update_group_log(g_name,user_name)
    "【#{user_name}】さんがグループ名【#{g_name}】の情報を更新しました"
  end
  
  #アイテムを新規に追加した時のログ文章作成
  def add_item_log(item_name, user_name)
    "【#{user_name}】さんが【#{item_name}】を追加しました"
  end
  
  #アイテムを更新した時のログ文章作成
  def update_item_log(item_name, user_name)
    "【#{user_name}】さんが【#{item_name}】の計画を更新しました"
  end
  
  #アイテムを削除した時のログ文章作成
  def delete_item_log(item_name, user_name)
    "【#{user_name}】さんが【#{item_name}】を削除しました"
  end
  
  #アイテムを削除した時のログ文章作成
  def rtn_personal_item_log(item_name, user_name)
    "【#{user_name}】さんが【#{item_name}】を個人メモに戻しました"
  end
  
  #アイテムを一致した時のログ文章作成
  def match_item_log(item_name_1, item_name_2, user_name)
    "【#{user_name}】さんが【#{item_name_1}】と【#{item_name_2}】を一致させました"
  end
  
  #ユーザーを招待した時のログ文章作成
  def invita_user_log(user_name)
    "【#{user_name}】さんを招待しました"
  end
  
  #招待したユーザーが承認した時のログ文章作成
  def join_user_log(user_name)
    "【#{user_name}】さんが参加しました"
  end
  
  #招待したユーザーが拒否した時のログ文章作成
  def reject_user_log(user_name)
    "【#{user_name}】さんが参加を断りました"
  end
  
  #ユーザーが自分で退会した時のログ文章作成
  def leave_user_log(user_name)
    "【#{user_name}】さんが退会しました"
  end
  
  #グループ作成者がユーザーを削除した時のログ文章作成
  def delete_user_log(create_user_name, del_user_name)
    "【#{create_user_name}】さんが【#{del_user_name}】さんを退会させました"
  end
end
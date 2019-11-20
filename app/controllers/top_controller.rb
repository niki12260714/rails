class TopController < ApplicationController
  before_action :sign_in_required, only: [:show, :invitation]
  include Log
  
  def home
    if user_signed_in?
      #ログインしていたら、showページに飛ばす
      redirect_to top_show_path
    end
  end
  
  def show
    #システムからのお知らせを取得する
    @system_info = Information.where("? BETWEEN info_start_date AND info_end_date", Date.today)
    #自分宛てに招待が行われているかを取得する
    @invite_info = GroupMember.joins(group: :user).merge(Group.get_future_group).where(user_id: current_user.id, join_status: false).preload(group: :user)
    #本日が買出し日のグループがあるかを確認する
    @purchase_group_info = Group.get_group_list_today(current_user.id)
    #今後のイベント計画があるかを確認する
    @group_list = Group.get_group_list_future(current_user.id).all.includes(group_members: :user).order(purchase_day: :asc, id: :asc)
    #個人アイテムがあるか確認する
    @items = Item.get_personal_item(current_user.id)
    #memo:View側での表示優先度はイベント当日＞システムからのお知らせ＞イベント計画
  end
  
  def thank
  end
  
  def rule
  end
  
  def links
  end
  
  def invitation
    #招待されたグループ情報を取得
    @group = Group.find_by(id: params[:g_id])
  end
  
  def join
    Group.transaction do
      #渡されたgroup_memberのidを更新し、グループログを更新する
      gm = GroupMember.find_by(id: params[:gm_id])
      gm.join_status = true
      gl = GroupLog.new(group_id: gm.group_id, log: join_user_log(current_user.nickname))
      gl.save!
      gm.save!
      flash[:success] = "グループへの招待を承認しました。"
      #トランザクション終了
    end
    redirect_to top_show_path
    #以下トランザクションで失敗した時の挙動記述
    rescue => e
      flash[:danger] = e.message
      redirect_to top_show_path
  end
  
  def reject
    Group.transaction do
      #渡されたgroup_memberのidを削除し、グループログを更新する
      gm = GroupMember.find_by(id: params[:gm_id])
      gl = GroupLog.new(group_id: gm.group_id, log: reject_user_log(current_user.nickname))
      gl.save!
      gm.destroy!
      flash[:success] = "グループへの招待を拒否しました。"
      #トランザクション終了
    end
    redirect_to top_show_path
    #以下トランザクションで失敗した時の挙動記述
    rescue => e
      flash[:danger] = e.message
      redirect_to top_show_path
  end
  
  def change_purchase_status
    GroupMember.transaction do
      status = 1
      #押されたボタンがsaveでなければ病欠ステータスとする
      if params[:save].nil?
        status = 3
      end
      #hiddenフィールドのgroup.idをもとに、グループメンバーの購入ステータスを更新
      params[:g_id].each do |gid|
        gm = GroupMember.find_by(group_id: gid, user_id: current_user.id)
        gm.member_purchase_status = status
        gm.save!
      end
      flash[:success] = "購入状況を更新しました"
      #トランザクション終了
    end
    redirect_to shopping_own_path
    #以下トランザクションで失敗した時の挙動記述
    rescue => e
      flash[:danger] = e.message
      redirect_to top_show_path
  end
end

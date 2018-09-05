class GroupsController < ApplicationController
  layout 'top'
  before_action :authenticate_user!
  before_action :set_group, only: [:edit, :update, :destroy, :invitation, :delete_member, :plan, :delete_item]
  include Log, Withdrawal, Buy
  
  def list
    #買出し日が本日以降かつ自分がグループメンバーになっているグループの一覧を取得する
    #ソートは買出し日の昇順
    @group_list = Group.get_group_list_future(current_user.id).all.includes(group_members: :user).paginate(page: params[:page], per_page: 10).order(purchase_day: :asc, id: :asc)
  end

  def new
    if @group.nil? then @group = Group.new() end
  end

  def edit
    #グループメンバー一覧を取得してくる
    @group_member = GroupMember.get_group_member(params[:id])
  end
  
  def create
    #チェックモデルにいれて、エラーチェック
    gc = Gpcheck.new(group_name: params[:group][:group_name], group_memo: params[:group][:group_memo], purchase_day: params[:group][:purchase_day])
    if !gc.valid?
      @errors = gc.errors
    else
      group = Group.new(group_params)
      group.create_user_id = current_user.id
      group.end_flg = false
      #グループとグループメンバーの親子インスタンス作成（グループ作成時、メンバーに自分を入れておく）
      group.group_members.build(user_id: current_user.id, join_status: true, member_purchase_status: 0)
      #グループとグループログの親子インスタンス作成（新規作成のログを作成）
      group.group_logs.build(log: create_group_log(group.group_name, current_user.nickname))
      #グループをDBに保存
      if group.save
        flash[:success] = "新しいイベント計画を作成しました。"
      else
        @errors = group.errors
      end
    end
  end
  
  def update
    #チェックモデルにいれて、エラーチェック
    gc = Gpcheck.new(group_name: params[:group][:group_name], group_memo: params[:group][:group_memo], purchase_day: params[:group][:purchase_day])
    if !gc.valid?
      @errors = gc.errors
    else
      if @group.update(group_params)
        gl = GroupLog.new(group_id: @group.id, log: update_group_log(@group.group_name, current_user.nickname))
        if gl.save
          flash[:success] = "イベント計画を更新しました。"
        else
          @errors = gl.errors
        end
      else
        @errors = @group.errors
      end
    end
  end
  
  def destroy
    Group.transaction do
      del_group(@group.id)
      flash[:success] = "イベント計画を削除しました。設定されていたアイテムは個人メモに戻ります。"
    end
    redirect_to groups_path
    #以下トランザクションで失敗した時の挙動記述
    rescue => e
      flash[:danger] = e.message
      redirect_to groups_path
  end
  
  def delete_member
    Group.transaction do
      if params[:member].size != 0
        params[:member].each do |uid|
          #一人ずつ削除し、ログを作成
          del_member(params[:id], uid)
          del_user = User.find_by(id: uid)
          gl = GroupLog.new(group_id: params[:id], log: delete_user_log(current_user.nickname, del_user.nickname))
          gl.save!
        end
      end
      #メンバー削除による残ったアイテムの情報を整理する※メンバーが抜けたことにより、グループの中で誰も購入希望がないアイテムを削除する
      #itemsで、配下のwant_countの合計が0のものを抽出し、削除する
      sigle_item = PurchaseMember.find_by_sql(["select a.id as i_id from (select MAX(item_id) as id, sum(want_count) as cnt from purchase_members where group_id = 28 group by purchase_id) a where a.cnt = 0", params[:id].to_i])
      if sigle_item.size != 0
        sigle_item.each do |si|
          #Purchase,PurchaseMemberはアソシエーションで一緒に消える
          Item.find_by(id: si.i_id).destroy!
        end
      end

      flash[:success] = "メンバーを削除しました。"
    end
    #redirect_to edit_group_path(@group)
    redirect_to groups_path
    #以下トランザクションで失敗した時の挙動記述
    rescue => e
      flash[:danger] = e.message
      redirect_to groups_path
  end
  
  def leave
    Group.transaction do
      del_member(params[:id], current_user.id)
      #ログ作成
      gl = GroupLog.new(group_id: params[:id], log: leave_user_log(current_user.nickname))
      gl.save!
      flash[:success] = "イベント計画から退会しました。"
    end
    redirect_to groups_path
    #以下トランザクションで失敗した時の挙動記述
    rescue => e
      flash[:danger] = e.message
      redirect_to groups_path
  end
  
  def invitation
    respond_to do |format| 
      format.html{} 
      format.js {} 
    end
    @group_member = GroupMember.new
  end
  
  def search_member
    #入力されたシステムIDを元にユーザーを検索
    if !params[:twitter].nil? then flg = "twitter_acount" else flg = "system_id" end
    chk_invitation(flg, params[:group_id], params[:system_id])
  end
  
  def insert_member
    #パラメーターで送信されたユーザーが存在し、かつイベント計画メンバーでないことを確認する
    chk_invitation("user_id", params[:group_id], params[:invite_user_id])
    if @invitation_user.size != 0 and @invitation_user.first.gid.nil?
      #グループに紐づくグループメンバー、グループログを生成する
      group = Group.find(params[:group_id])
      group.group_members.build(user_id: params[:invite_user_id].to_i, join_status: false, member_purchase_status: 0)
      group.group_logs.build(log: invita_user_log(params[:invite_user_name]))
      
      if group.save
        flash[:success] = "ユーザーに招待依頼を行いました。"
      else
        flash[:danger] = "保存に失敗しました"
      end
    else
      flash[:danger] = "競合が発生しました。画面をリロードし、データを確認してください。"
    end
    redirect_to groups_path
  end
  
  def checkpay
    #現時点での清算予定を取得
    get_result_items(params[:id], current_user.id, 0)
  end

  private
    def set_group
      @group = Group.find(params[:id])
    end
    
    def group_params
      params.require(:group).permit(:group_name, :purchase_day, :group_memo)
    end
    
    def chk_invitation(flg, g_id, second_param)
      sql = "SELECT users.id as uid, users.nickname, group_members.id as gid FROM users LEFT OUTER JOIN group_members ON group_members.user_id = users.id AND group_members.group_id = ? WHERE delete_flg is NULL AND "
      if flg == "system_id"
        sql += "users.system_id = ?"
      elsif flg == "twitter_acount"
        sql += "users.twitter_acount = ?"
      else
        sql += "users.id = ?"
      end
      @invitation_user = User.find_by_sql([sql, g_id, second_param])
    end
end

class HistoryController < ApplicationController
  layout 'top'
  before_action :authenticate_user!
  include Buy, Withdrawal
  
  def index
    #年月ドロップダウン作成(自分参加しているイベント計画の月日だけになるよう修正)
    dates= Group.get_group_list_all(current_user.id).\
                  select("CONCAT(YEAR(purchase_day),'-',MONTH(purchase_day),'-1') as ym, CONCAT(YEAR(purchase_day),'年',LPAD(MONTH(purchase_day),2,0),'月') as val").\
                  distinct.order("val desc")
    @date_array = []
    @date_array << ["開催月を選択",""]
    dates.each do |d|
      @date_array << [d.val,d.ym]
    end
    @group_array = [["イベントを選択",""]]
    @member_array = [["メンバーを選択",""]]
  end
  
  def get_group
    #選択された年月に買出し日があったグループのリストを取得
    date = params[:date].to_date
    group = Group.joins(:group_members).merge(GroupMember.get_member(current_user.id)).where(purchase_day: [date..date.end_of_month]).order("groups.purchase_day desc")
    render json: group.select("groups.id AS id, CONCAT(group_name,'(',YEAR(purchase_day),'/',MONTH(purchase_day),'/',DAY(purchase_day),')') AS name")
  end
  
  def get_member
    #選択されたグループに紐づくメンバーを取得
    member = GroupMember.joins(:user).where(group_id: params[:g_id])
    render json: member.select("group_members.user_id AS id, users.nickname AS name, CASE WHEN group_members.user_id = " + current_user.id.to_s + " THEN 1 ELSE 0 END AS ownselect")
  end
  
  def search
    #Active Modelに一旦詰めてエラーチェック
    chk_model = HistorySearch.new(group: params[:group_select], member: params[:member_select])
    if !chk_model.valid?
      @errors = chk_model.errors
      return
    end
    #正常ならば、パラメータをセッションに保持する
    session["history_group"] = params[:group_select]
    session["history_member"] = params[:member_select]
    
    #グループ概要取得
    get_group_overview(params[:group_select])
    
    #グループが締めてあるかをチェックし、締めていなければ未購入リストを表示、購入チェック
    @group_chk = Group.find_by(id: params[:group_select])
    if !@group_chk.end_flg
      get_not_buy_items(params[:group_select])
      @cr = "hs"
      @g_id = params[:group_select]
      return
    end
    
    #一部購入のデータを取得する
    get_part_items(params[:group_select])
    if @purchase.size == 0
      #一部購入が無ければ、最終精算画面を表示
      get_result_items(params[:group_select], params[:member_select], 1)
      @u_id = params[:member_select]
    end
  end
  
  def adjustment
    #割当を行うアイテム情報を取得する
    @purchase = Purchase.includes(:item).includes(purchase_members: :user).find_by(id: params[:p_id])
  end
  
  def do_adjustment
    #Active Modelに一旦詰めてエラーチェック
    chk_model = Adjustment.new(want_count: params[:want_count], p_count: params[:p_count])
    if !chk_model.valid?
      @errors = chk_model.errors
      return
    end
    
    #戻りの値を設定しておく
    if params[:rtn].nil? then @rtn = "history" else @rtn = "sp" end
    
    Purchase.transaction do
      p = Purchase.includes(:item).find_by(id: params[:p_id])
      #ループで割当欄を回し、purchase_memberを入力値に従って更新する
      params[:want_count].zip(params[:pm_id]).each do |want_count, pm_id|
        pm = PurchaseMember.find_by(id: pm_id)
        if want_count.to_i == 0
          #割当が0ならば、新たなpurchase_memberを生成し、個人設定を作成する
          create_new_personal_item(pm.item_id, pm.user_id, pm.group_id)
        end
        #want_countを入力値に更新する
        pm.want_count = want_count.to_i
        pm.save!
      end
      #purchaseの購入ステータスを更新する
      p.item_purchase_status = 1
      p.save!
      
      #一部購入のデータを取得する
      get_part_items(p.group_id)
      get_group_overview(p.group_id)
    end
    #以下トランザクションで失敗した時の挙動記述
    rescue => e
      @orignal_error_message = e.message
  end
  
  def circle_list
    #全アイテム情報出力出力
    @g_item = Purchase.where(group_id: params[:id]).joins(:item).preload(:item).distinct
    respond_to do |format|
      format.html
      format.csv do
        filename = "一括登録用サークル一覧"
        headers['Content-Disposition'] = "attachment; filename=\"#{filename}.csv\""
      end
    end
  end
  
  def result_list
    #購入結果出力
    @g_item = PurchaseMember.where(user_id: params[:u_id], group_id: params[:g_id]).where.not(want_count: 0).joins(:purchase).joins(:item).where("purchases.item_purchase_status = ?", 1).distinct
    g_info = Group.find_by(id: params[:g_id])
    respond_to do |format|
      format.html
      format.csv do
        filename = "購入結果(#{g_info.group_name})"
        headers['Content-Disposition'] = "attachment; filename=\"#{filename}.csv\""
      end
    end
  end
  
  private
  def get_group_overview(id)
    #グループ概要情報取得
    @group = Group.find(id)
    @g_member = GroupMember.get_group_member(id).where(join_status: true)
  end
  
end

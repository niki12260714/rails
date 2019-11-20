class ShoppingController < ApplicationController
  layout 'shop'
  before_action :authenticate_user!
  before_action :check_groups
  before_action :get_group_overview, only: [:group, :result]
  before_action :set_seach_list, only:[:correction]
  include Buy, Withdrawal
  
  def own
    #自分の買い物（アイテム順）
    if params[:mode].nil?
      #プレビューモードではない場合
      own_shopping_item(current_user.id, params[:page], params[:colum], params[:sort])
    else
      own_shopping_item_preview(current_user.id, params[:page], params[:colum], params[:sort], params[:id])
    end
    @rtn = "own"
  end
  
  def circle_view
    #自分の買い物（サークル順一覧）
    own_shopping_item_by_block(current_user.id, params[:block_no], params[:mode], params[:id])
  end
  
  def circle_view_detail
    #自分の買い物（サークル詳細)
    #postで渡ってきた時は、postで渡された値をセッションに詰めておく
    if request.post? 
      session[:circle_info] = {item_ids: params[:item_ids], join_circle_number: params[:join_circle_number], \
                              circle_name_first: params[:circle_name_first], display_block_no: params[:display_block_no] }
    end
    session[:circle_info].symbolize_keys!
    own_shopping_circle_detail(current_user.id, session[:circle_info][:item_ids].to_s)
  end
  
  def correction
    #自分の買い物で購入済みを取得
    if params[:search].nil? then @search = 0 else @search = params[:search] end
    own_shopping_end_item(current_user.id, @search)
  end
  
  def search_correction
    #自分自身にリダイレクト
    r_path = "#{shopping_correction_path}/#{params[:search].to_s}"
    redirect_to r_path
  end
  
  def status
    #ステータス変更対象データ取得
    p = Purchase.joins(:item).select("items.price, items.item_name, items.novelty_flg as nv, purchases.item_purchase_status, purchases.purchase_count").find_by(id: params[:p_id])
    #ShoppingStatusモデルを組み立てる
    # 購入ステータスが未購入の時はparamus[:count]、購入済みの場合はpurchase_countが実数(p_count)になる
    if p.item_purchase_status.to_i != 0 then p_cnt = p.purchase_count else p_cnt = params[:count] end
    @ss = ShoppingStatus.new(item_name: p.item_name, price: p.price, p_count: p_cnt, max_count: params[:count], novelty_flg: p.nv, item_purchase_status: p.item_purchase_status)
  end
  
  def save_status
    #Active Modelに一旦詰めてエラーチェック
    chk_model = ShoppingStatus.new(price: params[:shopping_status][:price], p_count: params[:shopping_status][:p_count], max_count: params[:shopping_status][:max_count], novelty_flg: params[:shopping_status][:novelty_flg])
    if !chk_model.valid?
      @errors = chk_model.errors
      return
    end

    #購入数によりステータスを切り分け
    if params[:shopping_status][:p_count].to_i == 0
      st = 2
    elsif params[:shopping_status][:max_count].to_i > params[:shopping_status][:p_count].to_i
      st = 3
    else
      st = 1
    end
    
    #値段、購入ステータス、購入数を更新する（購入担当をログインユーザーとするのは、精算から〇を押したときの処理のため）
    p = Purchase.find_by(id: params[:p_id])
    p.item_purchase_status = st
    p.purchase_count = params[:shopping_status][:p_count]
    p.purchase_user_id = current_user.id
    i = Item.find_by(id: p.item_id)
    i.novelty_flg = params[:shopping_status][:novelty_flg]
    i.price = params[:shopping_status][:price]
     
    Item.transaction do
      p.save!
      i.save!
      flash[:success] = "購入ステータスを更新しました"
      #トランザクション終了
    end
    #呼び出し元に従って処理を切り分けるための目印
    if params[:rtn].nil? then @rtn = "shopping" else @rtn = params[:rtn] end
    if @rtn == "hs"
      #戻り先が履歴ならば、未購入一覧とグループ概要を取得
      get_not_buy_items(params[:g_id])
      get_group_overview_by_id(params[:g_id])
      @cr = "hs"
      @group_chk = Group.find_by(id: params[:g_id])
    end
    #以下トランザクションで失敗した時の挙動記述
    rescue => e
      flash[:danger] = e.message
      redirect_to top_show_path
  end
  
  def save_bad
    p = Purchase.find_by(id: params[:p_id])
    p.item_purchase_status = 2
    p.purchase_count = 0
    if p.save
      flash[:success] = "購入ステータスを更新しました"
    else
      flash[:danger] = p.errors
    end
    rtn_path = ""
    if params[:rtn].nil?
      rtn_path = shopping_own_path
    elsif params[:rtn] == "shopping_end"
      rtn_path = shopping_result_path + "/" + params[:g_id]
    elsif params[:rtn] == "circle_view"
      rtn_path = shopping_circle_view_detail_path
    end
    if rtn_path != "" 
      redirect_to rtn_path
    else
      #戻り先が履歴ならば、未購入一覧とグループ概要を取得
      get_not_buy_items(params[:g_id])
      get_group_overview_by_id(params[:g_id])
      @cr = "hs"
      @group_chk = Group.find_by(id: params[:g_id])
    end
  end

  def group
    if !params[:id].nil?
      #購入ステータスの配列を設定
      get_p_status
      #モーダルウィンドウの戻り先を設定
      @rtn = "group"
      
      #検索からの戻りであれば、検索実行
      if !params[:search].nil?
        #検索実行
        get_by_purchase_status(params[:id], params[:search], params[:member], params[:page], params[:colum], params[:sort])
        #検索したグループ情報を取得（もし検索結果が0件だとしても、締めボタンを表示するから、検索からグループを求めない）
        @group = Group.find_by(id: params[:id])
        #hidden_fieldに渡すため、パラメータを変数に渡しておく※columとsortはget_by_purchase_statusでやっている
        @search = params[:search]
        @member = params[:member]
        @group_id = params[:id]
      else
        #初期表示であれば、初期値を設定
        @col = "space_number"
        @sort = "asc"
        @search = "0"
        @member = "all"
        @group_id = params[:id]
      end
    else
      flash[:danger] = "画面が正しく動作しませんでした。前の画面に戻ってから操作してください。"
      redirect_to top_show_path
    end
  end
  
  def search
    #自分自身にリダイレクト
    r_path = shopping_group_path + "/" + params[:group_id].to_s + "/" + params[:search].to_s + "/" + params[:member] + "/" + params[:colum] + "/" + params[:sort]
    redirect_to r_path
  end
  
  def group_end
    Item.transaction do
      #未購入のステータスを購入不可に変更する
      Purchase.where(group: params[:group_id].to_i, item_purchase_status: 0).update_all(item_purchase_status: 2, purchase_count: 0)
      #購入不可のアイテムを個人に戻すため、新たなItemとPurchaseMemberを生成する
      pa = Purchase.where(group: params[:group_id].to_i, item_purchase_status: 2).joins(:purchase_members).joins(:item).preload(:item).preload(:purchase_members).distinct
      pa.each do |p|
        p.purchase_members.each do |pm|
          create_new_personal_item(pm.item_id, pm.user_id, pm.group_id) if pm.want_count > 0
        end
      end
      #グループの締めフラグを立てる
      group = Group.find_by(id: params[:group_id])
      group.end_flg = true
      group.save!
      
      flash.now[:success] = "グループを締めました。"
      #トランザクション終了
    end
    if params[:rtn] == "shopping_end"
      rtn_path = shopping_result_path + "/" + params[:group_id]
      redirect_to rtn_path and return
    else
      #履歴からの締めの場合、次の画面の為に一部購入一覧とグループ概要を取得
      get_part_items(params[:group_id])
      get_group_overview_by_id(params[:group_id])
      if @purchase.length == 0
        get_result_items(session["history_group"], session["history_member"], 1)
      end
      @group_chk = Group.find_by(id: params[:group_id])
    end
    #以下トランザクションで失敗した時の挙動記述
    rescue => e
      flash[:danger] = e.message
      redirect_to top_show_path
  end
  
  def result
     #選択されたグループが締められているかをチェックし、締められていなければ未購入一覧を取得
    if !@group.end_flg
      get_not_buy_items(params[:id])
      return
    end
    
    #一部購入があるかチェック
    get_part_items(params[:id])
    if @purchase.size == 0
      #一部購入が無ければ、最終集計を取得（ユーザー視点はログインユーザー固定）
      get_result_items(params[:id], current_user.id, 1)
    else
      #一部購入の戻り先はイベント当日の目印を打つ
      @rtn = "shopping"
    end
  end
  
  def change_member
    #自分自身にリダイレクト
    r_path = shopping_group_path + "/" + params[:group_id].to_s + "/" + params[:search].to_s + "/" + params[:member] + "/" + params[:colum] + "/" + params[:sort]
    
    if !params[:purchase].nil? && params[:change_member] != "all"
      Purchase.where(id: params[:purchase]).update(purchase_user_id: params[:change_member])
      flash[:success] = "購入担当を変更しました。"
    else
      flash[:danger] = "購入担当を変更するアイテムと、担当者を選択してください。"
    end
    redirect_to r_path
  end
  
  private
  def set_group_status
    #2018/8/9 ステータス表示は一時停止
    #自分が所属するグループの全メンバーのステータス状況を取得する
    @group_status = Group.joins(:group_members).merge(GroupMember.where(user_id: current_user.id)).where(purchase_day: Date.today).includes(group_members: :user)
    @pu_status = [["未購入", "0"],["購入中", "1"], ["完了", "2"], ["病欠", "3"]]
  end
  
  def check_groups
    #本日が買出し予定日のグループ一覧を取得
    @groups = Group.get_group_list_today(current_user.id)
  end
  
  def get_group_overview
    #グループ概要情報取得(before_action用)
    get_group_overview_by_id(params[:id])
  end
  
  def get_group_overview_by_id(id)
    #グループ概要情報取得（引数でid持つパターン）
    @group = Group.find(id)
    @g_member = GroupMember.get_group_member(id).where(join_status: true)
    #検索の、メンバーのドロップダウン用の配列
    @s_member = Array.new()
    @s_member << ['購入担当','all']
    @g_member.each do |gm|
      @s_member << [gm.nickname, gm.user_id]
    end
    @s_member << ['未設定',"''"]
  end
  
  def set_seach_list
    #検索条件の配列作成
    @search_list = [["全件", "0"], ["購入できなかった", "1"], ["購入価格を0円に設定している", "2"], ["予定数より購入できなかった", "3"]]
  end
end

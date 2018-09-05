class RegistrationsController < Devise::RegistrationsController
  include Withdrawal
  include Log
  
  def after_sign_up_path_for(resource)
    top_thank_path
  end

  def after_inactive_sign_up_path_for(resource)
    top_thank_path
  end
  
  def destroy
    Group.transaction do
      #買出し日が明日以降で、自分が作成したグループを削除する
      create_groups = Group.get_group_list_future(current_user.id).where(create_user_id: current_user.id)
      if create_groups.size != 0
        create_groups.each do |cg|
          del_group(cg.id)
        end
      end
      
      #買出し日が明日以降で、自分が作成していないグループから退会する
      invita_groups = Group.get_group_list_future(current_user.id).where.not(create_user_id: current_user.id)
      if invita_groups.size != 0
        invita_groups.each do |ig|
          del_member(ig.id, current_user.id)
          #ログ作成
          gl = GroupLog.new(group_id: ig.id, log: leave_user_log(current_user.nickname))
          gl.save!
        end
      end
      
      #個人アイテムは全て削除する
      Item.joins(:purchase_members).where("purchase_members.group_id is null and purchase_members.user_id = ?", current_user.id).delete_all
      PurchaseMember.where(group_id: nil, user_id: current_user.id).delete_all
      
      # userモデルのsoft_deleteメソッドを呼び出す
      resource.soft_delete
    end
    #トップ画面に飛ばす
    redirect_to root
    #以下トランザクションで失敗した時の挙動記述
    rescue => e
      flash[:danger] = e.message
      redirect_to edit_user_registration_path
  end

  private
    def sign_up_params
      params.require(:user).permit(:system_id, :nickname, :email, :password, :password_confirmation)
    end
    
    def account_update_params
      params.require(:user).permit(:system_id, :nickname, :email, :password, :password_confirmation, :current_password)
    end
end
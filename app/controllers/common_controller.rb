class CommonController < ApplicationController
  #各種ページから共通的に呼び出されるAjax通信の関数の記載
  
  def change_pager
    #ページ数をセッションに設定
    if !params[:page].nil?
      session[:pager] = params[:page]
    end
    render json: '"success"'
  end
end

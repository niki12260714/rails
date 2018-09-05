class User < ApplicationRecord
  #Relation
  has_many :group_members
  has_many :purchase_members
  has_many :primary_members, foreign_key: 'purchase_user_id', class_name: 'Purchase'
  has_many :groups, through: :group_members
  has_many :groups, through: :purchase_members
  has_many :items, through: :purchase_members
  has_many :create_user, foreign_key: 'create_user_id', class_name: 'Group'
  
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :confirmable, :lockable, :timeoutable, :omniauthable, omniauth_providers: [:twitter]
  
  validates :nickname,
    presence: true,
    length: {maximum: 20}
  
  validates :system_id,
    uniqueness: true,
    length: {maximum: 50},
    format: { with: /\A[A-Za-z0-9\-_@]+$\z/ }
  
  def self.from_omniauth(auth)
    #emailは必須なので、omniauthの場合は「id@連携元」の形で一意のメールを作成する
    u = User.find_by(provider: auth["provider"], uid: auth["uid"])
    new_email = auth["uid"] + "@" + auth["provider"]
    if u.nil?
      nu = User.new(email: new_email, provider: auth["provider"], uid: auth["uid"], nickname: auth["info"]["name"], twitter_acount: auth["info"]["nickname"], password: Devise.friendly_token[0,20], system_id: new_email)
      #omniauthの場合、メール確認は飛ばす
      nu.skip_confirmation!
      nu.save
    else
      #最新のデータに上書き
      u.provider = auth["provider"]
      u.uid = auth["uid"]
      u.nickname = auth["info"]["name"]
      u.twitter_acount = auth["info"]["nickname"]
      u.email = new_email
      u.system_id = new_email
      u.save
    end
    User.find_by(provider: auth["provider"], uid: auth["uid"])
  end

  def self.new_with_session(params, session)
    if session["devise.user_attributes"]
      new(session["devise.user_attributes"]) do |user|
        user.attributes = params
      end
    else
      super
    end
  end
  
  def soft_delete
    update(delete_flg: true)
  end
  
  def active_for_authentication?
    !delete_flg && super
  end
  
  def inactive_message
    !delete_flg ? super : :deleted_account
  end
end

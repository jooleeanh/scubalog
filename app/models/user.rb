class User < ApplicationRecord
  TEMP_EMAIL_PREFIX = 'change@me'
  TEMP_EMAIL_REGEX = /\Achange@me/
  ADMINS = [
    "julian.honma@gmail.com",
    "nicolas.sitternolleau@yahoo.com",
    "personne6@hotmail.fr"
  ]

  # Include default devise modules. Others available are:
  # :lockable, :timeoutable
  devise :database_authenticatable, :registerable, :confirmable,
  :recoverable, :rememberable, :trackable, :validatable, :omniauthable

  validates_format_of :email, :without => TEMP_EMAIL_REGEX, on: :update
  has_many :identities, dependent: :destroy

  def self.find_for_oauth(auth, signed_in_resource = nil)

    # Get the identity and user if they exist
    identity = Identity.find_for_oauth(auth)

    # If a signed_in_resource is provided it always overrides the existing user
    # to prevent the identity being locked with accidentally created accounts.
    # Note that this may leave zombie accounts (with no associated identity) which
    # can be cleaned up at a later date.
    user = signed_in_resource ? signed_in_resource : identity.user
    email = auth.info.email # if email_is_verified

    user = set_user(email, auth)
    set_admin(user)
    set_image(user, auth)
    set_extra(user, auth)
    set_identity(user, identity)

    user.skip_confirmation! if user_complete_info?(user)
    user
  end

  def email_verified?
    self.email && self.email !~ TEMP_EMAIL_REGEX
  end

  def self.set_user(email, auth)
    user = User.where(email: email).first
    if user.nil?
      user = User.new unless user
      user.email = email
      set_info(user, auth)
    end
    user
  end

  def self.set_identity(user, identity)
    if identity.user != user
      identity.user = user
      identity.save!
    end
  end

  def self.set_extra(user, auth)
    user.update(gender: auth.extra.raw_info.gender)
  end

  def self.set_info(user, auth)
    name = auth.extra.raw_info.name
    first_name = auth.extra.raw_info.first_name || auth.info.first_name
    last_name = auth.extra.raw_info.last_name || auth.info.last_name
    email = user.email ? user.email : "#{TEMP_EMAIL_PREFIX}-#{auth.uid}-#{auth.provider}.com"

    user.update(
      name: name,
      first_name: first_name,
      last_name: last_name,
      email: email,
      password: Devise.friendly_token[0,20]
    )
  end

  def self.set_image(user, auth)
    case auth.provider
    when "google_oauth2" then user.update(google_picture_url: auth.info.image)
    when "facebook" then user.update(facebook_picture_url: auth.info.image)
    end
  end

  def self.set_admin(user)
    user.update(admin: true) if ADMINS.include?(user.email)
  end

  def self.user_complete_info?(user)
    user.respond_to?(:skip_confirmation) || user.email.nil?
  end
end

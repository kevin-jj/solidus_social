# frozen_string_literal: true

class Spree::UserAuthenticationsController < ('Spree::StoreController'.safe_constantize || ::StoreController)
  include SolidusSocial::StorefrontNavigation
  before_action :authenticate_spree_user!
  def index
    @authentications = spree_current_user.user_authentications if spree_current_user
  end

  def destroy
    @authentication = spree_current_user.user_authentications.find(params[:id])
    @authentication.destroy
    flash[:notice] = I18n.t('spree.destroy', scope: :authentications)
    redirect_to social_storefront.account_path
  end
end

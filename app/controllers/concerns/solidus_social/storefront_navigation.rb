# frozen_string_literal: true

module SolidusSocial
  module StorefrontNavigation
    private

    # Generated storefront routes live in the host app, not the Spree engine.
    def social_storefront
      'UserRegistrationsController'.safe_constantize ? main_app : spree
    end

    def after_sign_in_path_for(resource_or_scope)
      stored_location_for(resource_or_scope) || social_storefront.account_path
    end
  end
end

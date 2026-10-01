# frozen_string_literal: true

require_relative 'helper'
require_relative '../../app/controllers/concerns/solidus_social/storefront_navigation'

RSpec.describe 'Storefront navigation compatibility' do
  # Real route sets deliberately use distinct URLs to catch the wrong selection.
  let(:host_routes) do
    ActionDispatch::Routing::RouteSet.new.tap do |routes|
      routes.draw { get '/host/account', to: 'users#show', as: :account }
    end.url_helpers
  end
  let(:engine_routes) do
    ActionDispatch::Routing::RouteSet.new.tap do |routes|
      routes.draw { get '/engine/account', to: 'users#show', as: :account }
    end.url_helpers
  end

  let(:controller_class) do
    host = host_routes
    engine = engine_routes
    Class.new(ActionController::Base) do
      include SolidusSocial::StorefrontNavigation
      define_method(:main_app) { host }
      define_method(:spree) { engine }
      define_method(:stored_location_for) { |_resource| request.get_header('test.return_to') }
      def show
        redirect_to after_sign_in_path_for(:spree_user)
      end
    end
  end

  def response(return_to = nil)
    env = Rack::MockRequest.env_for('http://example.org/account')
    env['test.return_to'] = return_to
    controller_class.action(:show).call(env)
  end

  it 'redirects to the generated storefront account route' do
    stub_const('UserRegistrationsController', Class.new(ActionController::Base))
    expect(response[1]['location']).to eq('http://example.org/host/account')
  end

  it 'redirects to the engine account route for the legacy storefront' do
    hide_const('UserRegistrationsController')
    expect(response[1]['location']).to eq('http://example.org/engine/account')
  end

  it 'preserves the saved destination after login' do
    stub_const('UserRegistrationsController', Class.new(ActionController::Base))
    expect(response('/checkout/address')[1]['location']).to eq('http://example.org/checkout/address')
  end
end

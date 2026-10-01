# frozen_string_literal: true

# Run from the generated storefront host; never use a development database.
require 'uri'
unless ENV['RAILS_ENV'] == 'test' && URI.parse(ENV.fetch('DATABASE_URL', '')).path.end_with?('_test')
  abort 'Set RAILS_ENV=test and DATABASE_URL to an isolated database ending in _test'
end
require 'rails_helper'

RSpec.configure do |config|
  config.example_status_persistence_file_path = ENV['SOCIAL_TEST_STATUS_PATH'] if ENV['SOCIAL_TEST_STATUS_PATH']
end

RSpec.describe 'Social login on the generated storefront', type: :request do
  include Devise::Test::IntegrationHelpers

  around do |example|
    previous_mode = OmniAuth.config.test_mode
    previous_auth = OmniAuth.config.mock_auth.dup
    previous_providers = Spree::SocialConfig.providers
    OmniAuth.config.test_mode = true
    Spree::SocialConfig.providers = %i[google_oauth2 facebook].to_h do |provider|
      [provider, { api_key: 'test-client', api_secret: 'test-secret' }]
    end
    example.run
  ensure
    OmniAuth.config.test_mode = previous_mode
    OmniAuth.config.mock_auth = previous_auth
    Spree::SocialConfig.providers = previous_providers
  end

  before do
    unless Spree::Store.default.persisted?
      Spree::Store.create!(name: 'Test store', code: 'test', url: 'www.example.com',
        mail_from_address: 'store@example.com', default_currency: 'USD', default: true)
    end
    %w[google_oauth2 facebook].each do |provider|
      Spree::AuthenticationMethod.create!(provider: provider, environment: 'test', active: true)
    end
    get '/login'
  end

  %w[google_oauth2 facebook].each do |provider|
    context provider do
      let(:auth) do
        { provider: provider, uid: 'identity-123', info: { email: 'social@example.com' } }
      end

      def callback(provider, auth)
        OmniAuth.config.mock_auth[provider.to_sym] = OmniAuth::AuthHash.new(auth)
        get "/users/auth/#{provider}/callback"
      end

      it 'creates a user and redirects to the host account page' do
        expect { callback(provider, auth) }.to change(Spree::User, :count).by(1)
        expect(response).to redirect_to('/account')
        follow_redirect!
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('social@example.com')
      end

      it 'signs in a previously linked identity without creating another user' do
        user = Spree::User.create!(email: 'existing@example.com', password: 'test-password-123')
        user.user_authentications.create!(provider: provider, uid: 'identity-123')
        expect { callback(provider, auth) }.not_to change(Spree::User, :count)
        expect(response).to redirect_to('/account')
      end

      it 'links an identity to the signed-in user' do
        user = Spree::User.create!(email: 'existing@example.com', password: 'test-password-123')
        sign_in user
        callback(provider, auth)
        expect(user.user_authentications.reload.pluck(:provider)).to include(provider)
        expect(response).to redirect_to('/account')
      end

      it 'allows an identity without email to complete signup' do
        callback(provider, auth.merge(info: {}))
        expect(response).to redirect_to('/signup')
        follow_redirect!
        expect(response).to have_http_status(:ok)
        post '/signup', params: { spree_user: { email: 'completed@example.com' } }
        expect(Spree::User.find_by!(email: 'completed@example.com').user_authentications.count).to eq(1)
        expect(session[:omniauth]).to be_nil
      end

      it 'returns canceled authentication to the host login page' do
        OmniAuth.config.mock_auth[provider.to_sym] = :access_denied
        get "/users/auth/#{provider}/callback"
        expect(response).to redirect_to('/login')
      end
    end
  end

  it 'renders POST forms with Turbo disabled on both entry pages' do
    %w[/login /signup].each do |path|
      get path
      document = Nokogiri::HTML(response.body)
      %w[google_oauth2 facebook].each do |provider|
        form = document.at_css("form[action='/users/auth/#{provider}']")
        expect(form).not_to be_nil
        expect(form['method']).to eq('post')
        expect(form['data-turbo']).to eq('false')
      end
    end
  end

  it 'hides providers with missing credentials' do
    Spree::SocialConfig.providers[:facebook] = { api_key: nil, api_secret: nil }
    get '/signup'
    expect(response.body).not_to include('Continue with Facebook')
    expect(response.body).to include('Continue with Google')
  end

  it 'loads the registration decorator exactly once' do
    decorator = SolidusSocial::Spree::UserRegistrationsControllerDecorator
    expect(UserRegistrationsController.ancestors.count(decorator)).to eq(1)
  end
end

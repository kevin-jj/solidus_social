# frozen_string_literal: true

require_relative 'helper'

RSpec.describe 'Registration controller compatibility' do
  let(:decorator_path) do
    File.expand_path('../../app/decorators/controllers/solidus_social/spree/user_registrations_controller_decorator.rb', __dir__)
  end

  # Minimal host contract; the integration suite also exercises real Devise and
  # Spree::User. No decorator methods or callbacks are mocked here.
  let(:controller_class) do
    Class.new(ActionController::Base) do
      attr_reader :resource

      def create
        build_resource
        render plain: resource[:identities].length.to_s
      end

      private

      def build_resource
        @resource = Struct.new(:identities, :saved) do
          def apply_omniauth(identity)
            identities << identity
          end

          def persisted?
            saved
          end
        end.new([], request.get_header('test.saved'))
      end
    end
  end

  before do
    stub_const('Spree', Module.new)
    stub_const('SolidusSocial::Spree', Module.new)
  end

  def register(saved: true)
    env = Rack::MockRequest.env_for('http://example.org/signup', method: 'POST')
    env['rack.session'] = { omniauth: { 'provider' => 'google_oauth2', 'uid' => '123' } }
    env['test.saved'] = saved
    result = controller_class.action(:create).call(env)
    [result, env['rack.session']]
  end

  %w[UserRegistrationsController Spree::UserRegistrationsController].each do |name|
    context name do
      before do
        hide_const('UserRegistrationsController')
        stub_const(name, controller_class)
        load decorator_path
      end

      it 'applies the pending social identity and clears it after successful registration' do
        result, session = register
        expect(result[0]).to eq(200)
        expect(result[2].body).to eq('1')
        expect(session).not_to have_key(:omniauth)
      end

      it 'retains the pending identity when registration has not saved the user' do
        _result, session = register(saved: false)
        expect(session[:omniauth]).to include('uid' => '123')
      end

      it 'does not apply the identity twice when the decorator is loaded again' do
        load decorator_path
        result, = register
        expect(result[2].body).to eq('1')
        callbacks = controller_class._process_action_callbacks.select { |callback| callback.filter == :clear_omniauth }
        expect(callbacks.length).to eq(1)
      end
    end
  end
end

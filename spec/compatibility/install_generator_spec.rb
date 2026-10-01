# frozen_string_literal: true

require_relative 'helper'

RSpec.describe SolidusSocial::Generators::InstallGenerator do
  around do |example|
    Dir.mktmpdir('social-generator') do |directory|
      @destination = directory
      example.run
    end
  end

  let(:stylesheet) { File.join(@destination, 'vendor/assets/stylesheets/spree/frontend/all.css') }
  let(:generator) { described_class.new([], {}, destination_root: @destination) }

  it 'skips legacy stylesheet injection when the host does not have a manifest' do
    expect { generator.add_stylesheets }.not_to raise_error
    expect(File.exist?(stylesheet)).to be(false)
  end

  it 'injects the social stylesheet into the destination app, regardless of working directory' do
    FileUtils.mkdir_p(File.dirname(stylesheet))
    File.write(stylesheet, "/*\n *= require existing\n */\n")
    generator.add_stylesheets
    expect(File.read(stylesheet)).to include('require existing', 'require spree/frontend/solidus_social')
  end

  it 'does not duplicate the stylesheet directive on repeated installation' do
    FileUtils.mkdir_p(File.dirname(stylesheet))
    File.write(stylesheet, "/*\n */\n")
    2.times { generator.add_stylesheets }
    expect(File.read(stylesheet).scan('require spree/frontend/solidus_social').size).to eq(1)
  end
end

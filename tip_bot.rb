require "redis"
require "dry-initializer"
require "constructor_shortcut"
require "redis-namespace"
require "mobius/client"
require "pry-byebug" if ENV["MOBIUS_TIPBOT_ENVIRONMENT"] == "development"
require "tram-policy"

autoload :WithdrawCommandValidnessPolicy, "./tip_bot/telegram/policy/withdraw_command_validness_policy"
autoload :CreateCommandValidnessPolicy, "./tip_bot/telegram/policy/create_command_validness_policy"
autoload :StellarHelpers, "./tip_bot/utils/stellar_helpers"

module TipBot
  autoload :User,          "./tip_bot/user"
  autoload :TippedMessage, "./tip_bot/tipped_message"

  module Telegram
    module Command
      autoload :Balance,  "./tip_bot/telegram/command/balance"
      autoload :Base,     "./tip_bot/telegram/command/base"
      autoload :Start,    "./tip_bot/telegram/command/start"
      autoload :Tip,      "./tip_bot/telegram/command/tip"
      autoload :TipMenu,  "./tip_bot/telegram/command/tip_menu"
      autoload :MyAddress, "./tip_bot/telegram/command/my_address"
      autoload :Create, "./tip_bot/telegram/command/create"
      autoload :CreateAck, "./tip_bot/telegram/command/create_ack"
      autoload :Unregister, "./tip_bot/telegram/command/unregister"
      autoload :UnregisterAck, "./tip_bot/telegram/command/unregister_ack"
      autoload :Withdraw, "./tip_bot/telegram/command/withdraw"
    end

    module Service
      autoload :TipMessage, "./tip_bot/telegram/service/tip_message"
      autoload :CreateAddress, "./tip_bot/telegram/service/create_address"
      autoload :UnregisterAddress, "./tip_bot/telegram/service/unregister_address"
      autoload :Withdraw, "./tip_bot/telegram/service/withdraw"
    end

    autoload :Request,       "./tip_bot/telegram/request"
    autoload :TipKbMarkup,   "./tip_bot/telegram/tip_kb_markup"
    autoload :WebhookRouter, "./tip_bot/telegram/webhook_router"
  end

  class << self
    # Redis instance setter
    attr_writer :redis

    # Redis instance getter
    def redis
      @redis ||=
        (ENV["MOBIUS_TIPBOT_REDIS_URL"] || ENV["REDIS_URL"]) &&
        Redis::Namespace.new(
          :tipbot,
          redis: Redis.new(url: ENV["MOBIUS_TIPBOT_REDIS_URL"] || ENV["REDIS_URL"]),
        )
    end

    # Logger instance setter
    attr_writer :logger

    # Logger instance getter
    def logger
      @logger ||= Logger.new(STDOUT).tap { |l| l.level = Logger::INFO }
    end

    # Token setter
    attr_writer :token

    # Token getter
    def token
      @token ||= ENV["MOBIUS_TIPBOT_TOKEN"]
    end

    # Mobius::Client::App setter
    attr_writer :dapp

    # Mobius::Client::App getter
    def dapp
      @dapp ||= build_dapp
    end

    def app_account
      @app_account ||= Mobius::Client::Blockchain::Account.new(app_keypair)
    end

    def app_keypair
      @app_keypair ||= Mobius::Client.to_keypair(dapp.seed)
    end

    def pool_keypair
      @pool_keypair ||= Mobius::Client.to_keypair(dapp.address)
    end

    def pool_account
      @pool_account ||= Mobius::Client::Blockchain::Account.new(pool_keypair)
    end

    # Tip rate
    def tip_rate
      @tip_rate ||= (ENV["MOBIUS_TIPBOT_RATE"] || 1).to_f
    end

    # Sets up I18n and mobius client, then checks that required variables are present
    def configure!
      configure_i18n
      configure_mobius_client
      validate!
    end

    def chats_whitelist
      return if ENV["MOBIUS_TIPBOT_CHATS_WHITELIST"].nil?

      ENV["MOBIUS_TIPBOT_CHATS_WHITELIST"].split(",").map(&:to_i)
    end

    def development?
      ENV["MOBIUS_TIPBOT_ENVIRONMENT"] == "development"
    end

    private

    def validate!
      i18n_args = { scope: :errors, locale: :en }

      raise ArgumentError, I18n.t(:token_missing, i18n_args) if token.nil?
      raise ArgumentError, I18n.t(:redis_missing, i18n_args) if redis.nil?
      raise ArgumentError, I18n.t(:dapp_missing, i18n_args) if dapp.nil?
    end

    def configure_i18n
      I18n.load_path = Dir.glob(File.join(File.dirname(__FILE__), "locales/*.yml"))
      I18n.locale = ENV["MOBIUS_TIPBOT_LOCALE"] || :en
    end

    def configure_mobius_client
      Mobius::Client.network = ENV["MOBIUS_TIPBOT_NETWORK"] == "public" ? :public : :test
      asset_code = ENV["MOBIUS_TIPBOT_ASSET_CODE"]
      asset_issuer = ENV["MOBIUS_TIPBOT_ASSET_ISSUER"]

      if asset_code.nil? || asset_issuer.nil?
        return logger.warn(<<~MSG)
          You should provide both code and issuer, if you want to use custom Stellar asset for tips. Falling back to defaults (MOBI)
        MSG
      end

      Mobius::Client.asset_code = asset_code
      Mobius::Client.asset_issuer = asset_issuer
    end

    def build_dapp
      app_creds = ENV.values_at("MOBIUS_TIPBOT_APP_PRIVATE_KEY", "MOBIUS_TIPBOT_CREDIT_ADDRESS")
      Mobius::Client::App.new(*app_creds) unless app_creds.any?(&:nil?)
    end
  end
end

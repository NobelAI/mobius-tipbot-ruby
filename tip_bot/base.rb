class TipBot::Base
  extend Dry::Initializer
  extend Forwardable

  def_delegator :TipBot, :logger

  param :token
  param :rate
  param :dapp

  class << self
    def start!(*args)
      new(*args).start!
    end
  end

  def start!
    raise ArgumentError, "Provide #{self.class.name} token!" if token.nil? || token.empty?
    logger.info t(:hello)
  end

  protected

  def client
    raise NotImplementedError, "Replace with bot client instance constructor"
  end

  def receive(_message)
    raise NotImplementedError, "Replace with bot message parse command"
  end

  def say(_base_message, _text)
    raise NotImplementedError, "Replace with bot message send method"
  end

  def typing(_message); end

  def i18n_scope
    @i18n_scope ||= self.class.name.split("::").last.downcase
  end

  def t(*args, **kwargs)
    I18n.t(*args, { scope: i18n_scope }.merge(kwargs))
  end

  def app
    @app ||= TipBot::App.new(dapp)
  end

  def tip_value
    (rate || 1).to_f
  end

  def unknown(command, message)
    say(message, t(:"cmd.unknown", command: command))
  end

  def awaiting_cmd(message, nickname)
    user = TipBot::User.new(nickname, dapp)
    say(message, t(:"cmd.balance", balance: user.balance))
  end

  def tip_cmd(message, nickname, known)
    return say(message, t(:"cmd.tip.unknown_user")) unless known

    TipBot::User.new(nickname, dapp).tip(tip_value)

    say(message, t(:"cmd.tip.done", nickname: nickname))
  rescue Mobius::Client::Error::InsufficientFunds
    say(message, t(:"cmd.tip.insufficient_funds", nickname: nickname))
  rescue Mobius::Client::Error
    say(message, t(:"cmd.tip.error", nickname: nickname))
  end

  # rubocop:disable Metrics/AbcSize
  def withdraw_cmd(text, message, nickname)
    address = text.shift
    user = TipBot::User.new(nickname, dapp)
    return say(message, t(:"cmd.withdraw.address_missing")) if address.nil?
    return say(message, t(:"cmd.withdraw.nothing")) if user.balance.zero?
    user.withdraw(address)
    say(message, t(:"cmd.withdraw.done", address: address))
  rescue Mobius::Client::Error::UnknownKeyPairType
    say(message, t(:"cmd.withdraw.invalid_address", address: address))
  end
  # rubocop:enable Metrics/AbcSize

  def tip_value
    (rate || 1).to_f
  end  
end

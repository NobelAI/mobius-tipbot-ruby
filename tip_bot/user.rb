# Tip storage
class TipBot::User
  extend Dry::Initializer

  # @!method initialize(seed)
  # @param nickname [String] User nickname
  # @param dapp [Mobius::Client::App] Application instance
  # @!scope instance
  param :nickname
  param :dapp, default: -> { TipBot.dapp }

  # # Tips user for given value
  # # @param value [Float] Value in selected currency
  # def tip(value = TipBot.tip_rate)
  #   dapp.pay(value, target_address: address)
  #   increment(value) unless address
  # end

  # Address linked to user
  # @return [String] Stellar address
  def address
    TipBot.redis.hget(REDIS_ADDRESS_KEY, nickname)
  end

  def address=(address)
    TipBot.redis.hset(REDIS_ADDRESS_KEY, nickname, address)
  end

  # User balance
  # @return [Float] User balance
  def balance
    @balance ||= if stellar_account.nil?
                   TipBot.redis.hget(REDIS_BALANCE_KEY, nickname).to_f
                 else
                   stellar_account.balance.to_f
                 end
  end

  # Blocks user from sending tips for period
  def lock
    TipBot.redis.set(redis_lock_key, true, nx: true, ex: LOCK_DURATION)
  end

  # Returns true if user is not allowed to send tips.
  # @return [Boolean] true if locked
  def locked?
    (TipBot.redis.get(redis_lock_key) && true) || false
  end

  def increment_balance(value)
    TipBot.redis.hincrbyfloat(REDIS_BALANCE_KEY, nickname, value)
  end

  def decrement_balance(value)
    increment_balance(-value)
  end

  def stellar_account
    address && Mobius::Client::Blockchain::Account.new(Mobius::Client.to_keypair(address))
  end

  private

  def redis_lock_key
    "#{REDIS_LOCK_KEY}:#{nickname}".freeze
  end

  REDIS_ADDRESS_KEY = "address".freeze
  REDIS_BALANCE_KEY = "balance".freeze
  REDIS_LOCK_KEY = "lock".freeze
  LOCK_DURATION = 3600
end

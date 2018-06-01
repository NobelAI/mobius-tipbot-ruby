# Tip storage
class TipBot::User
  extend Dry::Initializer

  # @!method initialize(seed)
  # @param id [Integer] User Telegram id
  # @param dapp [Mobius::Client::App] Application instance
  # @!scope instance
  param :id
  param :dapp, default: -> { TipBot.dapp }

  # Address linked to user
  # @return [String] Stellar address
  def address
    value = TipBot.redis.hget(REDIS_ADDRESS_KEY, id)
    value&.empty? ? nil : value
  end

  def address=(address)
    if address.nil?
      TipBot.redis.hdel(REDIS_ADDRESS_KEY, id)
    else
      TipBot.redis.hset(REDIS_ADDRESS_KEY, id, address)
    end
  end

  # User balance
  # @return [Float] User balance
  def balance
    @balance ||= if stellar_account.nil?
                   redis_balance
                 else
                   stellar_account.balance.to_f
                 end
  end

  def redis_balance
    TipBot.redis.hget(REDIS_BALANCE_KEY, id).to_f
  end

  def merge_balances
    return if stellar_account.nil? || redis_balance.zero?

    TipBot.dapp.pay(redis_balance, target_address: stellar_account.keypair.address)
    TipBot.redis.hdel(REDIS_BALANCE_KEY, id)
  end

  # Blocks user from sending tips for period
  def lock
    TipBot.redis.set(redis_lock_key, true, nx: true, ex: LOCK_DURATION)
  end

  # Returns true if user is not allowed to send tips.
  # Users with registered custom Stellar accounts are never locked
  # @return [Boolean] true if locked
  def locked?
    return false unless stellar_account.nil?
    (TipBot.redis.get(redis_lock_key) && true) || false
  end

  def increment_balance(value)
    TipBot.redis.hincrbyfloat(REDIS_BALANCE_KEY, id, value)
  end

  def decrement_balance(value)
    increment_balance(-value)
  end

  def stellar_account
    address && Mobius::Client::Blockchain::Account.new(Mobius::Client.to_keypair(address))
  end

  private

  def redis_lock_key
    "#{REDIS_LOCK_KEY}:#{id}".freeze
  end

  REDIS_ADDRESS_KEY = "address".freeze
  REDIS_BALANCE_KEY = "balance".freeze
  REDIS_LOCK_KEY = "lock".freeze
  LOCK_DURATION = 3600
end

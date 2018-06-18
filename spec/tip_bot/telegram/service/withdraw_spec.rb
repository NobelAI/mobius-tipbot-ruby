RSpec.describe TipBot::Telegram::Service::Withdraw do
  let(:user) do
    TipBot::User.new(
      Telegram::Bot::Types::User.new(username: "john_doe")
    )
  end
  let(:user_balance) { 15 }
  let(:amount) { 5 }
  let(:destination_address) { "some_address" }

  subject { described_class.new(user, destination_address, amount) }

  before { allow(TipBot.dapp).to receive(:payout) }

  it "returns withdrawn amount" do
    expect(subject.call).to eq(amount)
  end

  context "when user doesn't have Stellar address attached" do
    before { user.increment_balance(user_balance) }

    it "withdraws via DAapp" do
      expect(TipBot.dapp).to \
        receive(:payout).with(amount, target_address: destination_address)
      subject.call
    end

    it "decrements user's balance" do
      subject.call
      expect(user.balance).to eq(user_balance - amount)
    end
  end

  context "when user has Stellar address attached" do
    before { user.address = "GDMHQDQZ4NKDIOH3UKKWNLGVUUF2WQX5B5KPZRUIHIP2BJOISZSERZUX" }

    it "withdraws from user's account" do
      expect(user).to receive(:transfer_money).with(amount, destination_address)
      subject.call
    end
  end
end

require 'rails_helper'

describe Messages::StatusTransition do
  describe '.allowed?' do
    [
      [:sent, :delivered, true],
      [:sent, :read, true],
      [:delivered, :read, true],
      [:sent, :sent, true],
      [:delivered, :delivered, true],
      [:read, :read, true],
      [:failed, :failed, true],
      [:delivered, :sent, false],
      [:read, :sent, false],
      [:read, :delivered, false],
      [:sent, :failed, true],
      [:delivered, :failed, false],
      [:read, :failed, false],
      [:failed, :sent, false],
      [:failed, :delivered, false],
      [:failed, :read, false]
    ].each do |from, to, expected|
      it "returns #{expected} for #{from} -> #{to} (symbols)" do
        expect(described_class.allowed?(from: from, to: to)).to be expected
      end

      it "returns #{expected} for #{from} -> #{to} (strings)" do
        expect(described_class.allowed?(from: from.to_s, to: to.to_s)).to be expected
      end
    end

    it 'returns false when the new status is outside the enum' do
      expect(described_class.allowed?(from: 'sent', to: 'pending')).to be false
      expect(described_class.allowed?(from: 'sent', to: nil)).to be false
    end

    it 'returns false for an unknown status even when from is nil' do
      expect(described_class.allowed?(from: nil, to: 'pending')).to be false
    end

    it 'allows the first assignment when from is nil or blank' do
      %w[sent delivered read failed].each do |status|
        expect(described_class.allowed?(from: nil, to: status)).to be true
        expect(described_class.allowed?(from: '', to: status)).to be true
      end
    end
  end
end

require 'rails_helper'

RSpec.describe Rede::Phone do
  describe '.normalize' do
    it 'normalizes real formats to E.164' do
      expect(described_class.normalize('(81) 9 8888-7777')).to eq('+5581988887777')
      expect(described_class.normalize('5581988887777')).to eq('+5581988887777')
      expect(described_class.normalize('+5581988887777')).to eq('+5581988887777')
      expect(described_class.normalize('+55 (81) 98888-7777')).to eq('+5581988887777')
      expect(described_class.normalize('081 98888-7777')).to eq('+5581988887777')
      expect(described_class.normalize('(81) 3222-1234')).to eq('+558132221234')
    end

    it 'keeps foreign numbers with plus sign' do
      expect(described_class.normalize('+1 415 555 2671')).to eq('+14155552671')
    end

    it 'returns nil for blank or invalid numbers' do
      expect(described_class.normalize(nil)).to be_nil
      expect(described_class.normalize('')).to be_nil
      expect(described_class.normalize('abc')).to be_nil
      expect(described_class.normalize('12345')).to be_nil
      expect(described_class.normalize('+0123456')).to be_nil
    end
  end

  describe '.variants' do
    it 'returns both forms for a Brazilian mobile with the ninth digit' do
      expect(described_class.variants('+5581988887777')).to eq(%w[+5581988887777 +558188887777])
    end

    it 'returns both forms for a Brazilian mobile without the ninth digit' do
      expect(described_class.variants('+558188887777')).to eq(%w[+558188887777 +5581988887777])
    end

    it 'has no variant for landlines' do
      expect(described_class.variants('+558132221234')).to eq(['+558132221234'])
    end

    it 'has no variant for non Brazilian numbers' do
      expect(described_class.variants('+14155552671')).to eq(['+14155552671'])
    end
  end
end

describe Bullet do
  describe 'initialization' do
    let(:args) { [1,2,3,4,5,6,7] }
    subject { described_class.new(*args) }

    it { is_expected.not_to be nil }
  end
end

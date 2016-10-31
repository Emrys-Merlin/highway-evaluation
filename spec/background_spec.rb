require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/pride'
require_relative '../background.rb'

describe Background do
  before do
    @td = Dir.mktmpdir('bg_spec')
  end

  after do
    FileUtils.remove_dir @td
  end

  describe '::new' do
    it 'checks that file exists.' do
      assert_raises do
        Background.new(@td + '/abc')
      end
    end
    it 'checks that column start exists.' do
      assert_raises do
        Background.new('./data/nostart.csv')
      end
    end
    it 'checks that column stop exists.' do
      assert_raises do
        Background.new('./data/nostop.csv')
      end
    end
    it 'checks that column date exists.' do
      assert_raises do
        Background.new('./data/nodate.csv')
      end
    end
    it 'checks that column tz exists.' do
      assert_raises do
        Background.new('./data/notz.csv')
      end
    end
    it 'converts start and stop to DateTime object' do
      bg = Background.new('./data/background.csv')
      assert_equal(DateTime.parse('2018-07-17 12:30:10+0000'), bg.df[:startdt][0])
      assert_equal(DateTime.parse('2018-07-17 12:30:15+0000'), bg.df[:stopdt][0])
    end
  end

  describe '#duration' do
    before do
      @bg = Background.new('./data/background.csv')
      @bg.duration
      @dur = Daru::Vector.new([5,47*60+28-(17*60+20)])
    end
    it 'computes the right duration' do
      assert_equal(@dur, @bg.df[:duration])
    end
    it 'checks for negative durations' do
      assert_raises do
        bg1 = Background.new('./data/negative.csv')
        bg1.duration
      end
    end
  end

  describe '#save' do

  end
end

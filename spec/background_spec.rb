# frozen_string_literal: true
require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/pride'
require_relative '../background.rb'

describe Background do
  before do
    @td = Dir.mktmpdir('bg_spec')
    @stop = DateTime.parse('2018-07-17 12:30:15+0000')
    @start = DateTime.parse('2018-07-17 12:30:10+0000')
    @bg = Background.from_csv('./data/background.csv')
  end

  after do
    FileUtils.remove_dir @td
  end

  describe '::new' do
    it 'checks that column start exists.' do
      assert_raises do
        Background.from_csv('./data/nostart.csv')
      end
    end
    it 'checks that column stop exists.' do
      assert_raises do
        Background.from_csv('./data/nostop.csv')
      end
    end
    it 'checks that column date exists.' do
      assert_raises do
        Background.from_csv('./data/nodate.csv')
      end
    end
    it 'checks that column tz exists.' do
      assert_raises do
        Background.from_csv('./data/notz.csv')
      end
    end
    it 'converts start and stop to DateTime object' do
      bg = Background.from_csv('./data/background.csv')
      assert_equal(@start, bg[:startdt][0])
      assert_equal(@stop, bg[:stopdt][0])
    end
  end

  describe '::from_csv' do
    it 'checks that file exists.' do
      assert_raises do
        Background.from_csv(@td + '/abc')
      end
    end
  end

  describe '#duration' do
    before do
      @bg = Background.from_csv('./data/background.csv')
      @bg.duration
      @dur = Daru::Vector.new([5, 47 * 60 + 28 - (17 * 60 + 20)])
    end
    it 'computes the right duration' do
      assert_equal(@dur, @bg[:duration])
    end
    it 'checks for negative durations' do
      assert_raises do
        bg1 = Background.from_csv('./data/negative.csv')
        bg1.duration
      end
    end
  end

  describe '#offset' do
    it 'adds a column with the constant offset' do
      vec = Daru::Vector[Array.new(@bg.nrows, 5)]
      @bg.offset(5)
      assert_equal(vec, @bg[:offset])
    end
  end

  describe '#average' do
    before do
      @av = Background.new(start: [],
                           stop: [],
                           date: [],
                           tz: [])
    end
  end

  describe '#retrieve_background' do
  end
end

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
    before do
      @offset = 5
      @vec = Daru::Vector[Array.new(@bg.nrows, @offset)]
      @bg2 = @bg.dup
      @bg.offset(@offset)
    end
    it 'adds a column with the constant offset' do
      assert_equal(@vec, @bg[:offset])
    end
    it 'adds the right offset to startdt and stopdt' do
      off = (@bg[:startdt][0] - @bg2[:startdt][0])*60*60*24
      assert_equal(@offset, off)
    end
  end

  describe '#write_csv' do
    before do
      @bg1 = Background.new(start: ['11:38:17'],
                          stop: ['11:40:45'],
                          date: ['08.11.2016'],
                          tz: ['utc'])
    end
    it 'writes a file' do
      path = @td + 'write_exist.csv'
      @bg.write_csv(path)
      assert(File.exist?(path))
    end
    it 'does not write statdt or stopdt' do
      @bg1.write_csv(@td + 'write.csv')
      df = DataFrame.from_csv(@td + 'write.csv')
      df.vectors = Index.new(df.vectors.to_a.map{|i| i.to_sym})
      assert_equal(df, @bg1[*(df.vectors.to_a)])
    end
  end

  describe '#retrieve_background' do
    before do
      @bg = Background.from_csv('./data/background.csv')
    end
    it 'computes the right background' do
      @bg.retrieve_background('./data/bg_nox.csv', :nox)
      assert_in_delta(3.5, @bg[:nox][0], 0.0001)
      assert_in_delta(10, @bg[:nox][1], 0.0001)
    end
  end
end

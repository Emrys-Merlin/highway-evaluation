# frozen_string_literal: true
require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/pride'
require_relative '../table.rb'

describe Background do
  before do
    @tb = Table.new({start: ['12:00:00'],
                     stop: ['12:05:00'],
                     date: ['07.07.2016'],
                     tz: ['utc']})
  end

  describe '#associate_background' do
    it 'associates the right background' do
      @tb.associate_background('./data/tb_background.csv',
                               :nox,
                               50,
                               3)
      assert_equal(1,@tb[:nox_background][0])
    end
  end

  describe '#find_min' do
    it 'checks for the right columns' do
      assert_raises do
        @tb.find_min('./data/table_nots.sv', :nox, 5)
      end
      assert_raises do
        @tb.find_min('./data/table_nonox.sv', :nox, 5)
      end
    end

    it 'finds the right minimum.' do
      @tb.find_min('./data/table.csv', :nox, 5)
      assert_equal(70, @tb[:nox_min][0])
      @tb.find_min('./data/table.csv', :nox, 3)
      assert_equal(80, @tb[:nox_min][0])
    end
  end
end

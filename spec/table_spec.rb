# frozen_string_literal: true
require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/pride'
require_relative '../table.rb'

describe Table do
  before do
    @tb = Table.new(start: ['12:00:00'],
                    stop: ['12:05:00'],
                    date: ['07.07.2016'],
                    tz: ['utc'])
  end

  describe '#assign_background' do
    it 'assigns the right background' do
      @tb.assign_background('./data/tb_background.csv',
                            :nox,
                            50,
                            3)
      assert_equal(1, @tb[:nox_background][0])
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

  describe '#co2_offset' do
    it 'adds a column with the constant offset' do
      vec = Daru::Vector[Array.new(@tb.nrows, 5)]
      @tb.co2_offset(5)
      assert_equal(vec, @tb[:co2_offset])
    end

    it 'returns a Table object' do
      assert(@tb.co2_offset(5).is_a?(Table))
    end
  end

  describe '#compute_ratio' do
    it 'computes the right ratio' do
      @tb[:nox_background] = Array.new(@tb.nrows, 0.0)
      @tb[:co2_background] = Array.new(@tb.nrows, 0.0)
      @tb.compute_ratio('./data/tb_nox.csv', './data/tb_co2.csv')
      assert_in_delta(5.5, @tb[:ratio][0], 0.0001)
    end
  end
end

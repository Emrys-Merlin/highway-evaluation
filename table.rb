#!/usr/bin/ruby
# coding: utf-8

require_relative 'background.rb'

# This class contains the table for one measurement day together with
# some helper methods to assign and correct for background and compute
# the ratios.
class Table < Background
  def initialize(path)
    super
  end

  def assign_background(bg_path, cns,
                        min_dur = 0, max_dist = Float::INFINITY)
    bg = load_bg(bg_path, min_dur)

    cns = [cns] unless cns.is_a?(Array)
    cns.each do |cn|
      self[(cn.to_s + '_background').to_sym] = Daru::Vector.new_with_size(nrows)
    end

    map_rows! do |row|
      start = row[:startdt]
      stop = row[:stopdt]

      cns.each do |cn|
        row[(cn.to_s + '_background').to_sym] = lookup(bg, cn, start,
                                                       stop, max_dist)
      end

      row
    end
  end

  # TODO: Fix such that NOx depends on CO2
  def find_min(raw_path, cn, interval)
    bg = DataFrame.from_csv(raw_path)
    bg.vectors = Index.new(bg.vectors.map(&:to_sym))

    residue = [:timestamp, cn] - bg.vectors.to_a
    raise "timestamp and #{cn} column necessary" unless residue.empty?

    interval = interval.to_f / (60.0 * 24.0)

    bg[:timestamp].map! do |t|
      DateTime.parse(t) if t.is_a?(String)
    end

    min = (cn.to_s + '_min').to_sym
    self[min] = Daru::Vector.new_with_size(nrows)

    map_rows! do |row|
      bstart = row[:startdt] - interval
      bstop = row[:startdt]
      astart = row[:stopdt]
      astop = row[:stopdt] + interval

      bi = bg[:timestamp].map do |t|
        (bstart <= t) && t < bstop ? true : false
      end

      ai = bg[:timestamp].map do |t|
        (astart <= t) && t < astop ? true : false
      end

      before = bg[cn].where(bi).min
      after = bg[cn].where(ai).min

      row[min] = [before, after].min
      row
    end
  end

  def compute_ratio(nox_path, co2_path, suffix = '_background')
    
  end

  def compute_correction
    self[:nox_corr] = Daru::Vector.new_with_size(nrows)
    self[:co2_corr] = Daru::Vector.new_with_size(nrows)

    df.map_rows! do |row|
      if row[:nox] < row[:nox_background] || row[:co2] < row[:co2_background]
        raise "Background too high at row #{row[:id]}."
      else
        row[:nox_corr] = row[:nox] - row[:nox_background]
        row[:co2_corr] = row[:co2] - row[:co2_background]
      end
      row
    end
  end

  private

  def load_bg(bg_path, min_dur)
    bg = DataFrame.from_csv(bg_path)
    bg.vectors = Index.new(bg.vectors.map(&:to_sym))
    bg = bg.where(
      bg[:duration].map do |d|
        d >= min_dur
      end
    )

    bg[:stopdt].map! do |s|
      DateTime.parse(s) if s.is_a?(String)
    end
    bg[:startdt].map! do |s|
      DateTime.parse(s) if s.is_a?(String)
    end
    bg
  end

  def lookup(bg, cn, start, stop, max_dist)
    before = bg.where(bg[:stopdt].map { |s| s < start }).last(1).row[0]
    after = bg.where(bg[:startdt].map { |s| s > stop }).first(1).row[0]

    db = (start - before[:stopdt]) * 24 * 60.to_f
    da = (after[:startdt] - stop) * 24 * 60.to_f

    unless db < max_dist || da < max_dist
      raise "No background value close enough."
    end

    (db < da ? before[cn] : after[cn])
  end
end

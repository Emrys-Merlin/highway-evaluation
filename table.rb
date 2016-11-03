#!/usr/bin/ruby

require_relative 'background.rb'

class Table < Background
  def initialize(path)
    super
  end

  def associate_background(bg_path, min_dur = 0, max_dist = Float::INFINITY)
    bg = DataFrame.from_csv(bg_path)
    bg.vectors = Index.new(bg.vectors.map{|i| i.to_sym})
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

    @df[:nox_background] = Daru::Vector.new_with_size(@df.nrows)
    @df[:co2_background] = Daru::Vector.new_with_size(@df.nrows)

    @df.map_rows! do |row|
      start = row[:startdt]
      stop = row[:stopdt]

      before = bg.where(bg[:stopdt].map{|s| s < start}).last(1).row[0]
      after = bg.where(bg[:startdt].map{|s| s > stop}).first(1).row[0]

      db = (start - before[:stopdt]) * 24 * 60.to_f
      da = (after[:startdt] - stop) * 24 * 60.to_f

      if db < max_dist or da < max_dist
        if db < da
          row[:nox_background] = before[:nox]
          row[:co2_background] = before[:co2]
        else
          row[:nox_background] = after[:nox]
          row[:co2_background] = after[:co2]
        end
      else
        raise "No background value close enough at row #{row[:id]}."
      end
      row
    end
  end

  # TODO Fix such that NOx depends on CO2
  def find_min(raw_path, interval)
    bg = DataFrame.from_csv(raw_path, cn)

    interval = interval.to_f/(60.0*24.0)

    min = (cn.to_s + "_min").to_sym
    @df[min] = Daru::Vector.new_with_size(@df.nrows)

    @df.map_rows! do |row|
      bstart = row[:start] - interval
      bstop = row[:start]
      astart = row[:stop]
      astop = row[:stop] + interval

      bi = bg[:timestamp].map do |t|
        bstart <= t and t < bstop ? true : false
      end

      ai = bg[:timestamp].map do |t|
        astart <= t and t < astop ? true : false
      end

      before = bg[cn].where(bi).min 
      after = bg[cn].where(ai).min

      row[min] = [before, after].min
    end
  end

  def compute_correction
    @df[:nox_corr] = Daru::Vector.new_with_size(@df.nrows)
    @df[:co2_corr] = Daru::Vector.new_with_size(@df.nrows)

    df.map_rows! do |row|
      unless row[:nox] < row[:nox_background] or row[:co2] < row[:co2_background]
        row[:nox_corr] = row[:nox] - row[:nox_background]
        row[:co2_corr] = row[:co2] - row[:co2_background]
      else
        raise "Background too high at row #{row[:id]}."
      end
      row
    end
  end
end

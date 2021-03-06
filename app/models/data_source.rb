class DataSource < ActiveRecord::Base
  #serialize :data, Hash
  serialize :dependencies, Array
  
  belongs_to :series
  has_many :data_points
  
  #DataSource.where("eval LIKE '%load_from%'").all.each {|ds| puts "#{ds.series.name} - #{ds.eval}" }
  
    def DataSource.type_buckets
      type_buckets = {:arithmetic => 0, :aggregation => 0, :share => 0, :seasonal_factors => 0, :mean_corrected_load => 0, :interpolation => 0, :sa_load => 0, :other_mathemetical => 0, :load => 0}
      all_evals = DataSource.all_evals
      all_evals.each do |eval|
        next if eval.nil?
        type_buckets[:arithmetic] += 1 unless eval.index(" + ").nil? and eval.index(" - ").nil? and eval.index(" / ").nil? and eval.index(" * ").nil? and eval.index(" ** ").nil? and eval.index("zero_add").nil? 
        type_buckets[:aggregation] += 1 unless eval.index("aggregate").nil?
        type_buckets[:share] += 1 unless eval.index("share").nil?
        type_buckets[:seasonal_factors] += 1 unless eval.index("seasonal_adjustment").nil?
        type_buckets[:mean_corrected_load] += 1 unless eval.index("load_mean_corrected_sa_from").nil?
        type_buckets[:sa_load] += 1 unless eval.index("load_sa_from").nil?
        type_buckets[:interpolation] += 1 unless eval.index("interpolate").nil?
        type_buckets[:other_mathemetical] += 1 unless eval.index("rebase").nil? and eval.index("annual").nil?
        type_buckets[:load] += 1 unless eval.index("load_from").nil?
      end
      type_buckets
    end

    #technically, this will not check for duplicate series
    #that are loading two seasonally adjusted source spreadsheets
    #but this should not happen, so not worried
    def DataSource.all_evals
      all_descriptions_array = []
      all_descriptions = DataSource.select(:eval).all
      all_descriptions.each {|ds| all_descriptions_array.push(ds.eval)}
      all_descriptions_array
    end

    def DataSource.handle_hash
      handle_hash = {}
      DataSource.where("eval LIKE '%load_from_download%'").select([:eval, :series_id]).all.each do |ds|
        handle = ds.eval.split("load_from_download")[1].split("\"")[1]
        handle_hash[ds.series_id] = handle
      end
      handle_hash
    end
    
    def DataSource.all_load_from_file_series_names
      series_names = []
      DataSource.where("eval LIKE '%load_from %'").all.each do |ds|
        series_names.push ds.series.name
      end
      series_names.uniq
    end
    
    #const is not there yet
    def DataSource.all_history_and_manual_series_names
      series_names = []
      ['sic','permits','agriculture','Kauai','HBR','prud','census','trms','vexp','hud','hiwi_upd','const_hist', 'tax_hist', 'tke'].each do |type| 
        DataSource.where("eval LIKE '%load_from %#{type}%'").each do |ds|
          series_names.push ds.series.name
        end
      end
      ['visusns', 'vrlsns', 'tke', 'tkb','vrdc', 'gffot', 'yl_o', 'yl_tu', 'yl_trade'].each do |type| 
        DataSource.where("eval LIKE '%#{type}%load_from %'").each do |ds|
          series_names.push ds.series.name
        end
      end

      series_names.push "PC_ANNUAL@HON.M"
      series_names.push "PCTRGSMD@HON.M"
      series_names.push "NTTOURNS@HI.M"
      series_names.uniq
    end
    
    # History
    # DataSource.where("eval LIKE '%sic%'").limit(5).each {|ds| puts ds.eval}; 0 (gets bls and bea SIC)
    # DataSource.where("eval LIKE '%permits%'").limit(5).each {|ds| puts ds.eval}; 0
    # DataSource.where("eval LIKE '%const%'").limit(5).each {|ds| puts ds.eval}; 0
    # prices SIC
    # Various 
    # YL
    
    # Manual
    # DataSource.where("eval LIKE '%agriculture%'").limit(10).each {|ds| puts ds.eval}
    # DataSource.where("eval LIKE '%Kauai%'").limit(5).each {|ds| puts ds.eval}
    # CAFRS?
    # DataSource.where("eval LIKE '%HBR%'").limit(5).each {|ds| puts ds.eval}
    # DataSource.where("eval LIKE '%prud%'").limit(5).each {|ds| puts ds.eval}
    # DataSource.where("eval LIKE '%census%'").limit(5).each {|ds| puts ds.eval}
    # DataSource.where("eval LIKE '%trms%'").limit(5).each {|ds| puts ds.eval}
    # DataSource.where("eval LIKE '%vexp%'").limit(5).each {|ds| puts ds.eval}
    # DataSource.where("eval LIKE '%hud%'").limit(5).each {|ds| puts ds.eval}; 0
    
    def DataSource.all_pattern_series_names
      series_names = []
      DataSource.where("eval LIKE '%load_from_pattern_id%' OR eval LIKE '%load_from_bls%' OR eval LIKE '%load_standard_text%'").all.each do |ds| 
        series_names.push ds.series.name
        #puts "#{ds.series.name} - #{ds.eval}"
      end
      series_names.uniq
    end
    
    def DataSource.pattern_only_series_names
      DataSource.all_pattern_series_names - DataSource.all_load_from_file_series_names
    end
    def DataSource.load_only_series_names
      DataSource.all_load_from_file_series_names - DataSource.all_pattern_series_names
    end
    def DataSource.pattern_and_load_series_names
      DataSource.all_pattern_series_names & DataSource.all_load_from_file_series_names
    end
    def DataSource.load_and_pattern_series_names
      DataSource.pattern_and_load_series_names
    end
    
    def DataSource.series_sources
      sa_series_sources = [] 
      DataSource.all_evals.each {|eval| sa_series_sources.push(eval) unless eval.index("load_sa_from").nil?}
      sa_series_sources
    end


    def DataSource.set_dependencies
      DataSource.all.each do |ds|
        ds.set_dependencies
      end
      return 0
    end

    def create_from_form
      Series.eval Series.find(self.series_id).name, self.eval
  #    puts "OK!"
      return true
    # rescue Exception
    #   puts "PROBLEM!!"
    #   return false
    end

    def setup
      self.set_dependencies
      self.set_color
    end

    def reload_source
      t = Time.now
      s = Kernel::eval self.eval
      self.series.update_data(s.data, self)
      #self.update_attributes(:description => s.name, :last_run => Time.now, :data => s.data, :runtime => (Time.now - t))
      #runtime is only updated here. could probably leave out of schema as well
      self.update_attributes(:description => s.name, :last_run => Time.now, :runtime => (Time.now - t))
    end

    # def mark_history
    #   #puts "SOURCE HISTORY-----------------------"
    #   dates = data.keys
    #   #puts dates.sort
    #   self.data_points.each do |dp| 
    #     #puts "history: #{dp.history}, date: #{dp.date_string}"
    #     dp.update_attributes(:history => nil) if (!dp.history.nil? and !dates.index(dp.date_string).nil?) 
    #     dp.update_attributes(:history => Time.now) if (dp.history.nil? and dates.index(dp.date_string).nil?)
    #   end
    # end

    def delete_all_other_sources
      s = self.series
      s.data_sources_by_last_run.each {|ds| ds.delete unless ds.id == self.id}
    end
    
    def DataSource.delete_related_sources_except(ids)
      ds_main = DataSource.find(ids[0])
      s = ds_main.series
      s.data_sources_by_last_run.each {|ds| ds.delete if ids.index(ds.id).nil?}
    end
        
        
    def current?
      self.series.current_data_points.each { |dp| return true if dp.data_source_id == self.id }
      return false
    rescue
      return false
    end
    
    def delete_no_series
      self.data_points.each do |dp|
        dp.delete
      end    
      super
    end
    
    def delete
      series_id = self.series_id
      self.data_points.each do |dp|
        dp.delete
      end    
      super
      s = Series.find series_id
  #    puts "Series name: #{s.name}, Sources:#{s.data_sources_by_last_run.count}"
  
    #put this in a separate function
      #s.data_sources_by_last_run.each {|ds| ds.reload_source}
    end


    def set_color
      color_order = ["FFCC99", "CCFFFF", "99CCFF", "CC99FF", "FFFF99", "CCFFCC", "FF99CC", "CCCCFF", "9999FF", "99FFCC"]
      #puts "#{self.id}: #{self.series_id}"
      other_sources = self.series.data_sources_by_last_run
      other_sources.each do |source|
        color_order.delete source.color unless source.color.nil?
      end
      self.color = color_order[0]
      self.save
    end

    def series
      Series.find self.series_id
    end

    def get_eval_statement
      "\"#{self.series.name}\".ts_eval= %Q|#{self.eval}|"
    end
    
    def print_eval_statement
      #might not need to do something different for seasonal adjustment anymore
      #if self.eval.index("apply_seasonal_adjustment").nil?
        #puts "\"#{self.series.name}\".ts_append_eval %Q|#{self.eval}|" if self.mode == "append"
        puts "\"#{self.series.name}\".ts_eval= %Q|#{self.eval}|" #if self.mode == "set"
      # else
      #         puts self.eval
      #       end
    end

    def set_dependencies
      self.dependencies = []
      self.description.split(" ").each do |word|
        unless (word.index('@').nil? or word.split(".")[-1].length > 1)
          self.dependencies.push(word)
        end
      end unless self.description.nil?
      self.dependencies.uniq!
      self.save
    end

    # def at(date_string)
    #   data[date_string]
    # end
end

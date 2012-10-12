#!/usr/bin/env ruby
# Copyright 2012 CopperEgg Corporation.  All rights reserved.
#
# fsdata_export.rb is a utility to export filesystem data from CopperEgg to an xlsx spreadsheet.
#
# TODO: add more granular time / date selection
# 
#encoding: utf-8

require 'rubygems'
require 'json'
require 'multi_json'
require 'axlsx'
require 'optparse'
require 'ostruct'
require 'pp'
require 'typhoeus'
require 'ethon'

$output_path = "." 
$APIKEY = ""
$filesystems95 = Array.new
$activefs = Array.new
$fs95num = 0
$actfsnum = 0
$live_systems_now = 0
$total_filesystems_now = 0
$verbose = false
$debug = false

class ExtractOptparse
  #
  # Return a structure containing the options.
  #
  def self.parse(args)
    # The options specified on the command line will be collected in *options*.
    # Set default values here.
    options = OpenStruct.new
    now = Time.now
    options.start_day = 1
    options.end_day = 1
    # default export interval is previous month
    if now.month == 1
      options.start_month = 12
      options.end_month = 1
      options.start_year = now.year-1
      options.end_year = now.year
    else
      options.start_month = now.month-1
      options.end_month = now.month
      options.start_year = now.year
      options.end_year = now.year
    end

    options.outpath = "."
    options.apikey = ""
    options.verbose = false
    options.sample_size_override = 0      # 86400
    options.interval = :pm                # ytd, pm, mtd
                                          # previous month is the default
    opts = OptionParser.new do |opts|
      opts.banner = "Usage: fsdata_export.rb APIKEY [options]"

      opts.separator ""
      opts.separator "Specific options:"

      opts.on("-o", "--Output path" , String, "Path to write .xlsx files") do |op|
        options.outpath = op
      end

      # Specify sample time override
      opts.on("-s", "--sample_size [SECONDS]", Integer, "Override default sample size") do |ss|
        options.sample_size_override = ss
      end
 
      # Optional argument with keyword completion.
      opts.on("-i", "--interval [INTERVAL]", String,[:ytd, :pm, :mtd, :l1, :l7,:l30, :l60, :l90],
              "Select interval (ytd, pm, mtd)") do |i|
        options.interval = i
        tmp = Time.now
        if i == :ytd
          options.start_month = 1
          options.end_month = tmp.month
          options.start_year = tmp.year
          if $verbose == true
            puts "Retrieving year to date data"
          end
        elsif i == :mtd 
          options.start_month = tmp.month
          options.end_month = tmp.month
          options.start_year = tmp.year
          options.end_day = tmp.day
          options.start_day = 1
          if tmp.day == 1
            puts "\nUse 'mtd' beginning on calendar day 2 of the month. For last 24 hours, use -i :l7\n"
            return nil
          else
            if $verbose == true
              puts "Retrieving month to date data"
            end
          end
        else
          if $verbose == true
            puts "Retrieving data from previous month"
          end
        end
      end
      # Boolean switch.
      opts.on("-v", "--verbose", "Run verbosely") do
        options.verbose = true
      end

      opts.separator ""
      opts.separator "Common options:"

      # No argument, shows at tail.  This will print an options summary.
      # Try it and see!
      opts.on_tail("-h", "--help", "Available options") do
        puts opts
        exit
      end

    end

    opts.parse!(args)
    options
  end  # parse()
end  # class ExtractOptparse


def valid_json? json_  
  begin  
    JSON.parse(json_)  
    return true  
  rescue Exception => e  
    return false  
  end  
end 


def find_systems _apikey
  begin 
    easy = Ethon::Easy.new(url: "https://"+$APIKEY.to_s+":U@api.copperegg.com/v2/revealcloud/systems.json", followlocation: true, verbose: false, ssl_verifypeer: 0, headers: {Accept: "json"}, timeout: 10000)
    easy.prepare
    easy.perform
  
    number_systems = 0
    live_systems = Array.new

    case easy.response_code
      when 200
        if valid_json?(easy.response_body) == true
          record = JSON.parse(easy.response_body) 
          if record.is_a?(Array)
            number_systems = record.length
            if number_systems > 0
              # filter out the hidden systems
              arrayindex = number_live = 0
              while arrayindex < number_systems
                if record[arrayindex]["hid"] == 0 
                  live_systems[number_live] = record[arrayindex]
                  number_live =  number_live + 1
                end # of 'if record[arrayindex]["hid"] == 0'
                arrayindex = arrayindex + 1
              end # of 'while arrayindex < number_systems'
              $live_systems_now = live_systems.length
              return live_systems
            else # no systems found
              puts "\nNo live systems found at this site. Aborting ...\n"
              return nil
            end # of 'if number_systems > 0'
          else # record is not an array
            puts "\nParse error: Expected an array. Aborting ...\n"
            return nil
          end # of 'if record.is_a?(Array)'
        else # not valid json
          puts "\nfind_systems: parse error: Invalid JSON. Aborting ...\n"
          return nil
        end # of 'if valid_json?(easy.response_body)' 
      when 404
        puts "\nfind_systems: HTTP 404 error returned. Aborting ...\n"
        return nil
      when 500...600
        puts "\nfind_systems: HTTP " +  easy.response_code.to_s +  " error returned. Aborting ...\n"
        return nil
    end # of switch statement
  rescue Exception => e  
    puts "Rescued in find_systems:\n"
    p e
    return nil 
  end
end

def to_spreadsheet(_fshash, _hostname)
  begin
    p = Axlsx::Package.new
    wb = p.workbook
    header = wb.styles.add_style :alignment => { :horizontal=> :center, :wrapText => true }
    date = wb.styles.add_style :alignment => { :horizontal=> :center }
    comma = wb.styles.add_style :num_fmt => 39, :alignment => { :horizontal => :center }
    fsnum = _fshash.length
    fskeys = _fshash.keys
    fsvals = _fshash.values        
    numentries = fsvals[0].length
    fsctr = 0

    if fsnum < 1
      puts "No filesystems found!\n"  
      return false 
    end # of ' if fsnum < 1'

    # Create a summary worksheet
    wb.add_worksheet(:name => "All Filesystems") do |sheet1|
      while fsctr < fsnum
        #puts "filesystem:\t" + fskeys[fsctr].to_s + " has \t" + fsvals[fsctr].length.to_s + "entries\n"
        if fsvals[fsctr].length != numentries
          puts "Error in to_spreadsheet: unequal arrays\n"
          #return false
        end # of 'if fsvals[fsctr].length != numentries'
        fsctr = fsctr + 1
      end # of ' while fsctr < fsnum'
      row0 = Array.new
      row0[0] = "Date & Time UTC"
      colctr = 1
      fsctr = 0
      style = Array.new
      widths = Array.new
      widths[0] = 2.3
      style[0] = date
      hdrstyle = Array.new
      hdrstyle[0] = header
      while fsctr < fsnum
        row0[colctr]=fskeys[fsctr].to_s + "        Used (gigabytes) "
        if fskeys[fsctr].to_s.length >= 18 
          widths[colctr] = ((fskeys[fsctr].to_s.length)/11).round(3)
          widths[colctr+1] = ((fskeys[fsctr].to_s.length)/11).round(3)
        else
          widths[colctr] = 1.26   # (" Used (gigabytes) ").length
          widths[colctr+1] = 1.26 # (" Used (gigabytes) ").length
        end
        row0[colctr+1]=fskeys[fsctr].to_s + "        Free (gigabytes)"
        style[colctr] = comma
        style[colctr+1] = comma
        hdrstyle[colctr] = header
        hdrstyle[colctr+1] = header
        colctr = colctr + 2
        fsctr = fsctr + 1
      end # of 'while fsctr < fsnum'
      sheet1.add_row row0, :style => header
      sheet1.column_info[0].width = 2.3
      colctr = 1
      fsctr = 0  
      while fsctr < fsnum
        sheet1.column_info[colctr].width = widths[colctr]
        sheet1.column_info[colctr+1].width = widths[colctr+1]
        colctr = colctr + 2
        fsctr = fsctr + 1
      end

      entrynum = 0
      while entrynum < numentries
        row0.clear
        fsctr = 0
        t_entry = Time.at(fsvals[fsctr][entrynum][0])
        if t_entry.utc? == false
          t_entry = t_entry.utc
        end # of 't_entry.utc? == false'
        row0[0] = t_entry.to_s
        while fsctr < fsnum
          if fsvals[fsctr][entrynum][1] == ""
            row0[1+(fsctr*2)] = ""
          else
            row0[1+(fsctr*2)] = (fsvals[fsctr][entrynum][1])/1000
          end
          if fsvals[fsctr][entrynum][2] == ""
            row0[2+(fsctr*2)] = ""
          else
            row0[2+(fsctr*2)] = (fsvals[fsctr][entrynum][2])/1000
          end
          fsctr = fsctr + 1
        end # of 'while fsctr < fsnum'
        sheet1.add_row row0, :style=> style
        entrynum = entrynum + 1
      end # of 'while entrynum < numentries'
    end # of 'add_worksheet'

    # Create one worksheet per filesystem
    fsctr = 0
    while fsctr < fsnum
      fs = "fs"+ (fsctr + 1).to_s
      wb.add_worksheet(:name => fs) do |sheet|           
        row = Array.new
        row[0] = "Date & Time UTC"
        row[1]=fskeys[fsctr].to_s + " Used (gigabytes)"
        row[2]=fskeys[fsctr].to_s + " Free (gigabytes)"
        row[3]=fskeys[fsctr].to_s + " Total (gigabytes)" 
        hdrstyle = [ header, header, header, header ]
        sheet.add_row row, :style => hdrstyle
        width = (" Total (gigabytes) ").length
        datewidth = ("2012-09-01 00:00:00 UTC".length)
        sheet.column_widths datewidth.to_i, width.to_i, width.to_i, width.to_i
  
        entrynum = 0 
        mostrecent = 0
        firstsample = -1
        while entrynum < numentries
          row.clear
          t_entry = Time.at(fsvals[fsctr][entrynum][0])
          if t_entry.utc? == false
            t_entry = t_entry.utc
          end  # of 't_entry.utc? == false'
          row[0] = t_entry.to_s
          if fsvals[fsctr][entrynum][1] == ""
            row[1] = ""
          else
            row[1] = (fsvals[fsctr][entrynum][1])/1000
          end
          if fsvals[fsctr][entrynum][2] == "" 
            row[2] = ""
          else
            row[2] = (fsvals[fsctr][entrynum][2])/1000
          end
          if (row[1] == "") || (row[2] == "")
            form = ""
          else      
            form = "=SUM(B"+(entrynum+2).to_s+":C"+(entrynum+2).to_s+")"
            mostrecent = entrynum
            if firstsample == -1
              firstsample = entrynum
            end
          end
          row[3] = form
          sheet.add_row row, :style=> [nil, comma, comma, comma]
          entrynum = entrynum + 1
        end # of 'while entrynum < numentries'
        # sheet.add_chart(Axlsx::Line3DChart, :title => fs,:rotX => 30, :rotY => 20 ) do |chart|
        if firstsample != -1 && mostrecent != 0
          sheet.add_chart(Axlsx::Line3DChart, :title => fskeys[fsctr].to_s,:rotX => 30, :rotY => 20 ) do |chart|
           # sheet.add_chart(Axlsx::Line3DChart, :title => fskeys[fsctr].to_s, :perspective => 0, :hPercent => 100, :rotX => 0, :rotY => 0) do |chart| 
            chart.start_at 1, (numentries+2)
            chart.end_at 30, (numentries+22)
            drange1 = "B2:B"+(numentries+1).to_s
            drange2 = "D2:D"+(numentries+1).to_s
            lrange =  "A2:A"+(numentries+1).to_s
            #puts "drange1 " + drange1 + "; drange2 " + drange2 + "; lrange " + lrange + "\n"
            chart.add_series :data => sheet[drange1], :labels => sheet[lrange], :title => sheet["B1"]
            chart.d_lbls.show_val = true
            chart.d_lbls.show_percent = true          
            chart.add_series :data => sheet[drange2], :labels => sheet[lrange], :title => sheet["D1"]
            chart.catAxis.title = 'Date'
            chart.catAxis.label_rotation = -45
            chart.valAxis.title = 'Gigabytes'
          end # of 'add Line3D chart' 
          fs = fs+":MostRecent"
          range = "B"+(mostrecent+2).to_s+":C"+(mostrecent+2).to_s
          sheet.add_chart(Axlsx::Pie3DChart, :start_at => [6,2], :end_at => [11,25 ], :title => fskeys[fsctr].to_s+ "  \nMost Recent  (in Gigabytes)") do |chart|
            #chart.add_series :data => sheet[range], :labels => sheet["B1:C1"],  :colors => ['FF0000', '00FF00', '0000FF']     
            chart.add_series :data => sheet[range], :labels => sheet["B1:C1"]     
            chart.d_lbls.show_val = true
            chart.d_lbls.show_percent = true
            chart.d_lbls.d_lbl_pos = :outEnd
            chart.d_lbls.show_leader_lines = true
          end # of add Pie Chart  
        end # of 'if firstsample != -1 && mostrecent != 0'
        fsctr = fsctr + 1
      end # of 'wb.add_worksheet'
    end # of 'while fsctr < fsnum'

    # Write the spreadsheet to disk
    if $output_path != "."
      if Dir.exists?($output_path.to_s+"/") == false
        if $verbose == true
          print "Creating directory..."
          if Dir.mkdir($output_path.to_s+"/",0775) == -1
            print "** FAILED ***\n"
            return false
          else
            FileUtils.chmod 0775, $output_path.to_s+"/"
            print "Success\n"
          end
        else
          if Dir.mkdir($output_path.to_s+"/",0775) == -1
            print "FAILED to create directiory "+$output_path.to_s+"/"+"\n"
            return false
          else
            FileUtils.chmod 0775, $output_path.to_s+"/"
          end
        end
      else  #  the directory exists
        FileUtils.chmod 0775, $output_path.to_s+"/"       # TODO only modify if needed? 
      end # of 'if Dir.exists?($output_path.to_s+"/") == false'
    end 
    if $verbose == true
      puts "Writing to "+$output_path.to_s+"/"+ _hostname+".xlsx\n\n"
    else
      print "."
    end
    p.serialize($output_path.to_s+"/"+ _hostname+".xlsx")
    return true
  rescue Exception => e
    puts "to_spreadsheet exception ... error is " + e.message + "\n"
    return false
  end
end

# fs_samples
# extract filesystem samples using CopperEggSamples
# returns a hash of arrays
#   {"filesystems95" => [{"uuid=> string, "fs"=> string , percentfull=> float, percentgain=> float}, ],   > 95% full at end of period
#    "mostactivefs" => {"uuid"=> string, "fs"=> string , percentfull=> float, percentgain=> float } }  10 filesystems having greatest increase during period

def fs_samples(_apikey,_uuid, _hostname, _keys, ts, te, ss)
  begin
    if ss != 0
      easy = Ethon::Easy.new(url: "https://"+$APIKEY.to_s+":U@api.copperegg.com/v2/revealcloud/samples.json?uuids="+_uuid.to_s+"&keys="+_keys.to_s+"&starttime="+ts.to_s+"&endtime="+te.to_s+"&sample_size="+ss.to_s, followlocation: true, verbose: false, ssl_verifypeer: 0, headers: {Accept: "json"}, timeout: 10000)
    else
      easy = Ethon::Easy.new(url: "https://"+$APIKEY.to_s+":U@api.copperegg.com/v2/revealcloud/samples.json?uuids="+_uuid.to_s+"&keys="+_keys.to_s+"&starttime="+ts.to_s+"&endtime="+te.to_s, followlocation: true, verbose: false, ssl_verifypeer: 0, headers: {Accept: "json"}, timeout: 10000)
    end     
    easy.prepare
    easy.perform
  
    case easy.response_code
      when 200
        if $verbose == true
          if ss == 0
            puts "Requested data for UUID "+_uuid+"; start date " + Time.at(ts).utc.to_s + "; end date " + Time.at(te).utc.to_s+"; default sample size\n"
          else
            puts "Requested data for UUID "+_uuid+"; start date " + Time.at(ts).utc.to_s + "; end date " + Time.at(te).utc.to_s+"; sample size "+ ss.to_s+"\n"       
          end
        end
        if valid_json?(easy.response_body) == true
          record = JSON.parse(easy.response_body)
          newhash = Hash.new
          full_period = Hash.new
          if record.is_a?(Array)
            full_period = record[0] 
            if (full_period["_ts"] != nil) && (full_period["_bs"] != nil) && (full_period["s_f"] != nil)
              base_time = full_period["_ts"]
              sample_time = full_period["_bs"]
              fs_hash = Hash.new
              fs_hash = full_period["s_f"]
     
              if $verbose == true
                puts "UUID actual start date "+ Time.at(base_time).utc.to_s + "; actual sample time " + sample_time.to_s + "\n" 
              end

              incr = sample_time.to_i
              fsarray = Array.new
              total_fs_cnt = 0
      
              # create a master bucket list for this sample set, to detect missing samples
              buckets = Array.new
              bucketoff = Array.new
              bucketcnt = 0
              off = 0
              t = ts
    
              while t <= te
                buckets[bucketcnt] = t
                bucketoff[bucketcnt] = off
                t = t + incr
                off = off + incr
                bucketcnt = bucketcnt + 1
              end
    
              # fs_hash looks like this:
              # "/boot"=>{ "0"=>[11.6, 76.24], ... , "86400"=>[11.6, 76.24] }
              # key is a string, value is a hash of key-values pairs  
              
              # Loop through all filesystems represented, and create a new validated and simple-to-parse hash  
    
              fs_hash.each do |key2,value2|     # stepping through each filesystem
                samples = Hash.new              # key2 is a filesystem name
                samples = value2                # samples is the samples hash
      
                # samples hash looks like this:
                # { "0"=>[11.6, 76.24], ... , "86400"=>[11.6, 76.24] }
                # key is offset from time 0, encoded as a string; value is a two-element array
    
                fsarray[total_fs_cnt] = key2.to_s   # store this filesystem name
                total_fs_cnt = total_fs_cnt + 1 
      
                # the new hash will look like this:
                # "/boot"=> [[ bassetime,11.6, 76.24], ... , [basetime+offset, 11.6, 76.24]]
                #puts "Next filesystem is " + key2.to_s + "\n"
                missctr = 0
                arrayctr = 0
                tmp = Array.new
          
                arrayctr = 0   
                lastsample = 0
                firstsample = -1
                # step through the expected offsets                    
                while arrayctr < bucketcnt
                  val = samples[bucketoff[arrayctr].to_s]
                  if val == nil
                    tmp[arrayctr] =  [buckets[arrayctr], "", ""]
                    missctr = missctr + 1
                  else
                    tmp[arrayctr] =  [buckets[arrayctr], val[0], val[1]] 
                    if firstsample == -1
                      firstsample = arrayctr
                    end
                    lastsample = arrayctr
                    #puts "last sample is "+lastsample.to_s+"\n\t"
                    #p tmp[lastsample]
                  end
                  arrayctr = arrayctr + 1
                end # end of this filesystem samples
                
                missctr = 0
                arrayctr = firstsample             
                while arrayctr <= lastsample
                  if tmp[arrayctr] ==  [buckets[arrayctr], "", ""]
                    missctr = missctr + 1
                  end
                  arrayctr = arrayctr + 1
                end # end of this filesystem samples

                # attempt to interpolate IFF a single data point is missing
                if missctr == 1
                  #puts "Doing interpolate on " +_hostname+ ", "+key2.to_s+"\n"
                  arrayctr = firstsample
                  while arrayctr <= lastsample
                    if tmp[arrayctr] == [buckets[arrayctr], "", ""]
                      if (arrayctr > 0) && (arrayctr < (bucketcnt-1))
                        new1 = tmp[arrayctr-1][1]
                        new2 = tmp[arrayctr-1][2]
                        new1 = new1 + tmp[arrayctr+1][1]
                        new2 = new2 + tmp[arrayctr+1][2]
                        new1 = new1/2.to_f
                        new2 = new2/2.to_f
                        tmp[arrayctr] =  [buckets[arrayctr], new1, new2]
                        arrayctr = bucketcnt      # force end of loop
                      end
                    end
                    arrayctr = arrayctr + 1
                  end
                end
                newhash[key2.to_s] = tmp 
                $total_filesystems_now = $total_filesystems_now + 1
                #add to fs95 if used/total > .95        
                if tmp[firstsample][1] != "" && tmp[firstsample][2] != "" && tmp[lastsample][1] != "" && tmp[lastsample][2] != "" 
                  pfull = tmp[lastsample][1] / (tmp[lastsample][1]+tmp[lastsample][2])

                  if  pfull > 0.95
                    h = Hash.new
                    h = { "uuid" => _uuid.to_s, "fs" => key2.to_s, "percentfull" => (pfull*100).round(2)}
                    $filesystems95[$fs95num] = h
                    $fs95num = $fs95num + 1
                  end
                  pchange =  tmp[lastsample][1] / tmp[firstsample][1]
                  if pchange > 1
                    h1 = Hash.new
                    h1 = { "uuid" => _uuid.to_s, "fs" => key2.to_s, "percentgain"=> (pchange*100).round(2), "percentfull" => (pfull*100).round(2)}
                    $activefs[$actfsnum] = h1
                    $actfsnum = $actfsnum + 1
                  end
                  #puts "filesystem " + key2.to_s + ": " + missctr.to_s + " missing samples\n"      
                end
              end   # end of fs_hash.each
              #p newhash
              if to_spreadsheet(newhash,_hostname) == true
                #puts "to_spread returned true\n"
                return true
              else
                puts "Error: to_spread returned false\n"
              end
            else  # base_time, sample_time or keys fields were nil
              puts "\nParse error: keys nil. Aborting ...\n"
            end       
          else    # else not an array
            puts "\nParse error: Expected an array. Aborting ...\n"
          end  
        else
          puts "\nParse error: Invalid JSON. Aborting ...\n"
        end
      when 404
        puts "\n HTTP 404 error returned. Aborting ...\n"
      when 500...600
        puts "\n HTTP " +  easy.response_code.to_s +  " error returned. Aborting ...\n"
    end
    return false
  end
end

#
# This is the main portion of the fsdata_export.rb utility
#
if ARGV[0] == nil
  puts "Usage: fsdata_extract.rb APIKEY [options]\n"
else 
  $APIKEY = ARGV[0]
  if $APIKEY == ""
    puts "Usage: fsdata_extract.rb APIKEY [options]\n"
  else
    options = ExtractOptparse.parse(ARGV)
  
    if options.verbose == true
      $verbose = true
    else
      $verbose = false
    end
    $output_path = options.outpath
    options.apikey = $APIKEY
  
    if $verbose == true
      pp options
      puts "\n"
    else
      puts "\n"
    end
  
    tstart = Time.gm(options.start_year,options.start_month,options.start_day,0,0,0)
    tend = Time.gm(options.end_year,options.end_month,options.end_day,0,0,0)
    ts = tstart.to_i 
    te = tend.to_i
    
    if tstart.utc? == false
      tstart = tstart.utc
    end
    if tend.utc? == false
      tend = tend.utc
    end
    
    numberlive = 0
    livesystems = Array.new
    livesystems = find_systems($APIKEY)
    if livesystems != nil
      #puts "find_systems returned an array!\n"
      numberlive = livesystems.length
      arrayindex = 0
      while arrayindex < numberlive
        #puts "Index "+arrayindex.to_s+": UUID "+livesystems[arrayindex]["uuid"]+"\n"
        #p livesystems[arrayindex]
        uuid = livesystems[arrayindex]["uuid"]
        attrs = livesystems[arrayindex]["a"]
        # filter out those not updated during this period
        if attrs["p"] > ts
          hostname = attrs["n"]
          if hostname == nil
            hostname = uuid
          else
            hostname = hostname+"-"+uuid
          end
          #puts "Index "+arrayindex.to_s+": hostname "+hostname+"\n"
          fs_samples($APIKEY, livesystems[arrayindex]["uuid"], hostname, "s_f", ts, te, options.sample_size_override )
        end
        arrayindex = arrayindex + 1
      end # of 'while arrayindex < numberlive'
      puts "\nSummary :\n" 
      puts "Total systems monitored this period: "+ $live_systems_now.to_s+"\n"   
      puts "Total filesystems monitored this period: "+$total_filesystems_now.to_s+"\n"
      todo = 0
      if $filesystems95.length > 0
        if $filesystems95.length == 1
          print "1 filesystem is > 95% full...it is: \n"
          todo = 1
        else
          print $filesystems95.length.to_s+ " filesystems are > 95% full..."      
          if $filesystems95.length > 10
            print "the top 10 are:\n"
            todo = 10
          else
            print "they are:\n"
            todo = $filesystems95.length
          end
        end
        $filesystems95 = $filesystems95.sort_by {|a| [ a["percentfull"], a["percentgain"] ] }.reverse
        ctr = 0
        while ctr < todo
          p $filesystems95[ctr]
          puts "\n"
          ctr = ctr+1
        end
        puts "\n"
      else
         puts "No filesystems > 95% full\n"
      end
      if $activefs.length > 0
        if $activefs.length == 1
          print "1 filesystem is growing...it is: \n"
          todo = 1
        else
          print $activefs.length.to_s+ " filesystems are growing ..."
          if $activefs.length > 10
            print "the top 10 growing most rapidly are:\n"
            todo = 10
          else
            print "they are:\n"
            todo = $activefs.length
          end
        end
        $activefs = $activefs.sort_by {|a| [ a["percentgain"], a["percentfull"] ] }.reverse
        ctr = 0
        while ctr < todo
          p $activefs[ctr]
          puts "\n"
          ctr = ctr+1
        end
        puts "\n"
      end
    else
      puts "find_systems returned nil\n"
    end # of 'if livesystems != nil'
  end # of 'if $APIKEY == ""'
end
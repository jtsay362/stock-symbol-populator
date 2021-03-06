require 'csv'
require 'uri'
require 'net/http'
require 'json'
require 'fileutils'

EXCHANGES = ['NASDAQ', 'NYSE', 'AMEX']
DOWNLOAD_DIR = './downloaded'

class StockSymbolPopulator

  def initialize(output_path)
    @output_path = output_path
  end

  def download
    puts "Starting download ..."

    FileUtils.mkpath(DOWNLOAD_DIR)

    EXCHANGES.each do |exchange|
      puts "Downloading CSV for #{exchange} ..."

      uri = URI.parse("http://www.nasdaq.com/screening/companies-by-industry.aspx?exchange=#{exchange}&render=download")
      response = Net::HTTP.get_response(uri)

      File.open("#{DOWNLOAD_DIR}/#{exchange.downcase}.csv", "w") do |out|
        line_number = 0
        response.body.each_line do |line|
          # Remove trailing comma on header line
          line = line.strip
          if line_number == 0
            line = line.slice(0, line.length - 1)
          end

          line_number += 1

          out.write(line)
          out.write("\n")
        end
      end
      puts "Done downloading page for <#{exchange}>, sleeping ..."
      sleep(1)
    end

    puts "Done downloading!"
  end

  def populate
    @first_document = true

    @num_symbols_found = 0

    File.open(@output_path, 'w:UTF-8') do |out|
      out.write <<-eos
{
  "metadata" : {
    "settings" : {
      "analysis": {
        "char_filter" : {
          "no_special" : {
            "type" : "mapping",
            "mappings" : ["^=>", "/=>", "$=>", ".=>", ":=>"]
          }
        },
        "analyzer" : {
          "lower_whitespace" : {
            "type" : "custom",
            "tokenizer": "whitespace",
            "filter" : ["lowercase"],
            "char_filter" : ["no_special"]
          }
        }
      }
    },
    "mapping" : {
      "_all" : {
        "enabled" : false
      },
      "properties" : {
        "exchange" : {
          "type" : "string",
          "index" : "no"
        },
        "symbol" : {
          "type" : "string",
          "index" : "analyzed",
          "analyzer" : "lower_whitespace"
        },
        "companyName" : {
          "type" : "string",
          "index" : "analyzed"
        },
        "marketCap" : {
          "type" : "float",
          "index" : "no"
        },
        "ipoYear" : {
          "type" : "integer",
          "index" : "no"
        },
        "sector" : {
          "type" : "string",
          "index" : "no"
        },
        "industry" : {
          "type" : "string",
          "index" : "no"
        },
        "suggest" : {
          "type" : "completion",
          "analyzer" : "lower_whitespace",
          "payloads" : true
        }
      }
    }
  },
  "updates" : [
    eos

      Dir["#{DOWNLOAD_DIR}/*.csv"].each do |file_path|
        parse_file(file_path, out)
      end

      out.write("\n  ]\n}")
    end

    puts "Found #{@num_symbols_found} symbols."
  end

  private

  def parse_file(file_path, out)
    simple_filename = File.basename(file_path)
    exchange = simple_filename.slice(0, simple_filename.length - 4).upcase

    puts "Parsing file '#{file_path}' for exchange #{exchange} ..."


    CSV.foreach(file_path, headers: true, header_converters: :symbol) do |row|
      #puts "row methods = " + row.methods.join(',')


      row.to_h.each_key do |k|
        if row[k]
          row[k] = row[k].strip
        end
      end

      output_doc = {
        exchange: exchange,
        symbol: row[:symbol],
        companyName: row[:name],
        marketCap: (row[:marketcap].to_f rescue nil),
        ipoYear: (row[:ipoyear].to_i rescue nil),
        sector: row[:sector],
        industry: row[:industry],
        suggest: {
          input: [row[:symbol], row[:name]],
          output: row[:symbol],
          payload: {
            desc: row[:symbol] + ': ' + row[:name]
          }
        }
      }

      if @first_document
        @first_document = false
      else
        out.write(",\n")
      end

      json_doc = output_doc.to_json
      out.write(json_doc)

      @num_symbols_found += 1
    end

    puts "Done parsing file for exchange #{exchange}."
  end
end

output_filename = 'stocks.json'

download = false

ARGV.each do |arg|
  if arg == '-d'
    download = true
  else
    output_filename = arg
  end
end

populator = StockSymbolPopulator.new(output_filename)

if download
  populator.download()
end

populator.populate()
system("bzip2 -kf #{output_filename}")
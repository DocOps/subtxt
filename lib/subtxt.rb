require "subtxt/version"
require 'optparse'
require 'logger'
require 'fileutils'

@ingestdir_def = "."
@filext_def = "*"
@expath_def = "_subtxt/output"

@options = {}
@options[:ingestdir] = @ingestdir_def
@options[:filext] = @filext_def
@options[:expath] = @expath_def

@logger = Logger.new(STDOUT)
@logger.level = Logger::WARN
@logger.formatter = proc do |severity, datetime, progname, msg|
  "#{severity}: #{msg}\n"
end

def load_patterns pfile
  records = []
  File.open(pfile, "r") do |pats|
    pair = {}
    rowct = 0
    pats.each_line do |row|
      break if row.chomp.downcase == "eof"
      unless pair['fnd'] and pair['rep']
        unless pair['fnd']
          pair['fnd'] = row.chomp
        else
          pair['rep'] = row.chomp
        end
      else
        records << pair
        pair = {}
      end
    end
  end
  return records
end

def subtexts opts
  patterns = load_patterns(opts[:patterns])
  @logger.info "Reading patterns from #{@options[:patterns]}"
  routine = {}
  routine['filesprocessed'] = 0
  routine['log'] = []
  Dir.glob(opts[:ingestpath]) do |f|
    text = File.read(f)
    @logger.debug "Processing file: #{File.basename(f)}"
    sandr = []
    patterns.each do |rec|
      ptn = rec['fnd']
      replace = rec['rep'].gsub(/\\n/, "\n")
      text.gsub!(/#{ptn}/, replace)
      if opts[:verbose] or opts[:debug]
        matches = text.gsub(/#{ptn}/).count
      end
      sandr << {:pattern => ptn, :matches => matches}
    end
    routine['log'] << {:file => f, :matchlog => sandr }
    unless opts[:expext]
      outfile = File.basename f
    else
      fn = File.basename(f,".*")
      outfile = "#{fn}.#{opts[:expext]}"
    end
    begin
      FileUtils::mkdir_p(opts[:expath]) unless File.exists?(opts[:expath])
      File.open("#{opts[:expath]}/#{outfile}", 'w') { |file| file.write(text) }
      @logger.debug "File saved (#{outfile})"
      routine['filesprocessed'] += 1
    rescue Exception => ex
      raise "Failure: #{ex}"
    end
    @logger.info display_results(routine)
  end
end

def display_results routine={}
  raise "NoRecordsFound" unless routine['log'].count
  output = ""
  routine['log'].each do |doc|
    output << "\nFile: #{doc[:file]}"
    output << "\nMatches:"

  end
  output
end

parser = OptionParser.new do|opts|
  opts.banner = """
  Subtxt is a simple utility for matching and replacing patterns in target text.
  It searches all of the files in a directory (optionally one type at a time)
  for multiple patterns, each with its own dynamic replcement. Subtxt uses Ruby
  regular expression (regex) patterns for matching and substituting text.
  Check out http://refiddle.com/ and http://www.rexegg.com/regex-quickstart.html

  Pattern files are formatted in 3-row sets. The first row is the find pattern,
  the second row is the replace pattern, and the third row delimits the set for
  the convenience of your eyeballs. Like so:
  \t---------------------------------------
  \tfind pattern
  \treplace pattern
  \t
  \t(pattern|string|content)-(to)-(find)
  \t$1 $2 replace
  \t
  \tregular expression pattern
  \ttokenized substitute output
  \t
  \tEOF
  \t---------------------------------------\n
  This procedure generates a copy of each file in a separate directory
  (#{@expath_def}/ by default) after replacing each matched pattern with
  its pair.

  Usage: subtxt [path/to/ingest/dir] [options]
  Options:
  """

  unless ARGV[0]
    @logger.error "You must at least provide a patterns file option. For help, use\nsubtxt --help"
    exit
  end

  if ARGV[0].split("").first == "-"
    opts.on('-i PATH', '--ingestdir PATH', "Ingest files from this directory. Defaults to current directory.\n\t\t\t\t\tSuperceded if a path is passed as the first argument\n\t\t\t\t\t(subtxt path/to/files -p patterns.rgx). Ex: -i path/to/ingest/dir") do |n|
      @options[:ingestdir] = n;
    end
  else # the first arg has no leading - or --, it must be our path
    @options[:ingestdir] = ARGV[0]
  end

  opts.on('-p PATH', '--patterns PATH', "Full (relative or absolute) path to a text file\n\t\t\t\t\tcontaining find & replace patterns in the designated format.\n\t\t\t\t\tREQUIRED. Ex: -p path/to/patterns.rgxp") do |n|
    @options[:patterns] = n;
  end

  ## TODO recursion
  # opts.on('-r', '--recursive', 'Whether to process the input directory recursively (traverse subdirectories).') do
  #   @options[:recursive] = true
  # end

  opts.on('-f STRING', '--filext STRING', "Restrict ingested files to this extension. The first dot (.) is implied.\n\t\t\t\t\tEx: -f htm") do |n|
    @options[:filext] = n;
  end

  opts.on('-x PATH', '--expath PATH', 'Location for saving the converted files. Ex: -x processed/files/dir') do |n|
    @options[:expath] = n;
  end

  opts.on('--expext STRING', "The export file\'s extension to reassign for all files. The first dot (.)\n\t\t\t\t\tis implied. Defaults to same extension as original. Ex: --expext htm") do |n|
    @options[:expext] = n;
  end

  opts.on('--verbose', 'Print INFO level logs to console.') do
    @options[:verbose] = true
  end

  opts.on('--debug', 'Print DEBUG (and INFO) level logs to console.') do
    @options[:debug] = true
  end

  opts.on('-h', '--help', 'Displays help menu') do
    puts opts
    exit
  end

  opts.on_tail('-v', 'Show Subtxt release version') do
    puts "You're using Subtxt v#{Subtxt::VERSION}"
    exit
  end
end
parser.parse!

# options postprocessing
@options[:ingestpath] = "#{@options[:ingestdir]}/*.#{@options[:filext]}"
if @options[:verbose]
  @logger.level = Logger::INFO
end
if @options[:debug]
  @logger.level = Logger::DEBUG
end

# call the proc
subtexts(@options)

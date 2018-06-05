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
  patterns_display = ""
  patterns.each do |rec|
    fndsize = rec['fnd'].size
    fndgap = 90 - fndsize
    if fndgap > 5
      gapspaces = "   "
      fndgap.times do gapspaces += "." end
    else
      gapspaces = fndgap
    end
    patterns_display += "\n#{rec['fnd']}#{gapspaces}=> #{rec['rep']}"
  end
  @logger.info "Using patterns:\n#{patterns_display}\n"
  Dir.glob(opts[:ingestpath]) do |f|
    text = File.read(f)
    @logger.debug "Processing file: #{File.basename(f)}"
    patterns.each do |rec|
      replace = rec['rep'].gsub(/\\n/, "\n")
      text.gsub!(/#{rec['fnd']}/, replace)
    end
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
    rescue Exception => ex
      raise "Failure: #{ex}"
    end
  end
end

parser = OptionParser.new do|opts|
  opts.banner = """
  Subtxt is a simple utility for matching and replacing patterns in target text.
  It searches all of the files in a directory (optionally one type at a time)
  for multiple patterns, each with its own dynamic replcement. Subtxt uses Ruby
  regular expression (regex) patterns for matching and substituting text.
  Check out http://refiddle.com/ and http://www.rexegg.com/regex-quickstart.html

  Pattern files are formatted in 3-row sets. The first row is the find pattern,
  the second row is the replace pattern, and he third row delimits the set for
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
  Usage: subtxt [path/to/ingest/dir] [options]
  Options:
  """

  unless ARGV[0]
    @logger.error "You must at least provide a patterns file option. For help, use\nsubtxt --help"
    exit
  end

  if ARGV[0].split("").first == "-"
    opts.on('-i', '--ingestdir', "Ingest files from this directory. Defaults to current directory. Superceded if a path is passed as\n\t\t\t\t\tthe first argument (subtxt path/to/files -p patterns.rgx). Ex: -i path/to/ingest/dir") do |n|
      @options[:ingestdir] = n;
    end
  else # the first arg has no leading - or --, it must be our path
    @options[:ingestdir] = ARGV[0]
  end

  opts.on('-p PATH', '--patterns PATH', "Full (relative or absolute) path to a text file containing find & replace patterns in the\n\t\t\t\t\tdesignated format. REQUIRED. Ex: -p path/to/patterns.rgxp") do |n|
    @options[:patterns] = n;
  end

  ## TODO recursion
  # opts.on('-r', '--recursive', 'Whether to process the input directory recursively (traverse subdirectories).') do
  #   @options[:recursive] = true
  # end

  opts.on('-f STRING', '--filext STRING', 'Restrict ingested files to this extension. The first dot (.) is implied. Ex: -f htm') do |n|
    @options[:filext] = n;
  end

  opts.on('-x PATH', '--expath PATH', 'Location for saving the converted files. Ex: -x processed/files/dir') do |n|
    @options[:expath] = n;
  end

  opts.on('--expext STRING', "The export file\'s extension to reassign for all files. The first dot (.) is implied. Defaults to same\n\t\t\t\t\textension as original. Defaults to #{@expath_def} Ex: --expext htm") do |n|
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

require "subtxt/version"
require 'optparse'
require 'logger'
require 'fileutils'
require 'yaml'

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

def load_patterns pfiles
  files = pfiles.split(",")
  records = []
  files.each do |pfile|
    File.open(pfile, "r") do |pats|
      pair = {}
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
  end
  return records
end

def subtexts opts
  unless opts[:patterns]
    @logger.error "Missing patterns file!"
    exit
  end
  patterns = load_patterns(opts[:patterns])
  @logger.info "Reading patterns from #{opts[:patterns]}"
  routine = {}
  routine['files_count'] = 0
  routine['files_changed'] = []
  routine['files_changed_count'] = 0
  routine['log'] = []
  Dir.glob(opts[:ingestpath]) do |f|
    text = File.read(f)
    @logger.debug "Processing file: #{File.basename(f)}"
    sandr = []
    patterns.each do |rec|
      fnd = rec['fnd']
      rep = rec['rep'].gsub('\n', "\n")
      rep = rep.gsub('\r', "\r")
      if opts[:verbose] or opts[:debug]
        matches = text.gsub(/#{fnd}/).count
        syms = text.gsub(/#{fnd}/) {|sym| "-#{sym}-"}
        if matches > 0
          sandr << {:pattern => fnd, :matches => matches, :syms => syms}
          unless routine['files_changed'].include? f
            routine['files_changed'] << f
          end
        end
      end
      text.gsub!(/#{fnd}/, rep)
    end
    if opts[:verbose] or opts[:debug]
      routine['log'] << {:file => f, :matchlog => sandr }
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
      routine['files_count'] += 1
    rescue Exception => ex
      raise "Failure: #{ex}"
    end
  end
  @logger.info display_results(routine)
end

def display_results routine={}
  raise "NoRecordsFound" unless routine['log'].count
  output = "Files processed: #{routine['files_count']}"
  output << "\nFiles changed: #{routine['files_changed'].size}"
  routine['log'].each do |doc|
    output << "\nFile: #{doc[:file]}"
    output << "\nMatches:"
    doc[:matchlog].each do |mch|
      output << "\n#{mch[:matches]}: #{mch[:pattern]}"
    end
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
  the convenience of your eyeballs. The file must terminate with an explicit
  ""EOF"" Like so:
  \t---------------------------------------
  \tfind pattern
  \treplace pattern
  \t
  \t(pattern|string|content)-(to)-(find)
  \t\1 \2 replace
  \t
  \tregular expression pattern
  \ttokenized substitute output
  \t
  \tEOF
  \t---------------------------------------\n
  This procedure generates a copy of each file in a separate directory
  (#{@expath_def}/ by default) after replacing each matched pattern with
  its pair.

  Usage: subtxt [path/to/patterns.ext] [options]
  Options:
  """

  unless ARGV[0]
    @logger.error "You must at least provide a patterns file argument. For help, use\nsubtxt --help"
    exit
  end

  if ARGV[0].split("").first == "-"
    opts.on('-p', '--patterns PATH[,PATH]', "Full (relative or absolute) path to a text file containing","find & replace patterns in the designated format.","REQUIRED. Ex: -p path/to/patterns.rgxp,path/to/secondary-patterns.txt") do |n|
      @options[:patterns] = n;
    end
  else # the first arg has no leading - or --, it must be our path
    @options[:patterns] = ARGV[0]
  end

  opts.on('-s PATH', '--source PATH', "Ingest files from this directory. Defaults to current directory.","\tSuperceded if a path is passed as the first argument","\t(subtxt path/to/files -p patterns.rgx). Ex: -i path/to/ingest/dir") do |n|
    @options[:ingestdir] = n;
  end

  ## TODO recursion
  # opts.on('-r', '--recursive', 'Whether to process the input directory recursively (traverse subdirectories).') do
  #   @options[:recursive] = true
  # end

  opts.on('-f STRING', '--filext STRING', "Restrict ingested files to this extension. The first dot (.) is implied.","\tEx: -f htm") do |n|
    @options[:filext] = n;
  end

  opts.on('-x PATH', '--expath PATH', 'Location for saving the converted files. Ex: -x processed/files/dir') do |n|
    @options[:expath] = n;
  end

  opts.on('--expext STRING', "The export file\'s extension to reassign for all files. The first dot (.)","is implied. Defaults to same extension as original. Ex: --expext htm") do |n|
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
    puts "You're using Subtxt v#{Subtxt::VERSION}. Get the latest with gem update subtxt"
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

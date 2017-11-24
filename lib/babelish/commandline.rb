require 'thor'
require 'yaml'
class Commandline < Thor
  include Thor::Actions
  class_option :verbose, :type => :boolean
  class_option :config, :type => :string, :aliases => "-c", :desc => "Read configuration from given file", :default => ".babelish"
  map "-v" => :version

  CSVCLASSES = [
    {:name => "CSV2Strings", :ext => ".strings"},
    {:name => "CSV2Android", :ext => ".xml"},
    {:name => "CSV2JSON", :ext => ".json"},
    {:name => "CSV2Php", :ext => ".php"},
  ]

  CSVCLASSES.each do |klass|
    desc "#{klass[:name].downcase}", "Convert CSV file to #{klass[:ext]}"
    method_option :filename, :type => :string, :aliases => "-i", :desc => "CSV file to convert from"
    method_option :langs, :type => :hash, :aliases => "-L", :desc => "Languages to convert. i.e. English:en"

    # optional options
    method_option :excluded_states, :type => :array, :aliases => "-x", :desc => "Exclude rows with given state"
    method_option :state_column, :type => :numeric, :aliases => "-s", :desc => "Position of column for state if any"
    method_option :keys_column, :type => :numeric, :aliases => "-k", :desc => "Position of column for keys"
    method_option :comments_column, :type => :numeric, :aliases => "-C", :desc => "Position of column for comments if any"
    method_option :default_lang, :type => :string, :aliases => "-l", :desc => "Default language to use for empty values if any"
    method_option :csv_separator, :type => :string, :aliases => "-S", :desc => "CSV column separator character, uses ',' by default"
    method_option :output_dir, :type => :string, :aliases => "-d", :desc => "Path of output files"
    method_option :output_basenames, :type => :array, :aliases => "-o", :desc => "Basename of output files"
    method_option :stripping, :type => :boolean, :aliases => "-N", :default => false, :desc => "Strips values of spreadsheet"
    method_option :ignore_lang_path, :type => :boolean, :aliases => "-I", :lazy_default => false, :desc => "Ignore the path component of langs"
    if klass[:name] == "CSV2Strings"
      method_option :macros_filename, :type => :boolean, :aliases => "-m", :lazy_default => false, :desc => "Filename containing defines of localized keys"
    end
    define_method("#{klass[:name].downcase}") do
      csv2base(klass[:name])
    end
  end

  BASECLASSES = [
    {:name => "Strings2CSV", :ext => ".strings"},
    {:name => "Android2CSV", :ext => ".xml"},
    {:name => "JSON2CSV", :ext => ".json"},
    {:name => "Php2CSV", :ext => ".php"},
  ]

  BASECLASSES.each do |klass|
    desc "#{klass[:name].downcase}", "Convert #{klass[:ext]} files to CSV file"
    method_option :filenames, :type => :array, :aliases => "-i", :desc => "location of strings files (FILENAMES)"

    # optional options
    method_option :csv_filename, :type => :string, :aliases => "-o", :desc => "location of output file"
    method_option :headers, :type => :array, :aliases => "-h", :desc => "override headers of columns, default is name of input files and 'Variables' for reference"
    method_option :dryrun, :type => :boolean, :aliases => "-n", :desc => "prints out content of hash without writing file"
    define_method("#{klass[:name].downcase}") do
      begin
        base2csv(klass[:name])
      rescue Errno::ENOENT => e
        warn e.message
      end
    end
  end

  desc "open FILE", "Open local csv file in default editor"
  def open(file = "translations.csv")
    filename = file || options["filename"]
    if File.exist?(filename)
      say "Opening local file '#{filename}'"
      system "open \"#{filename}\""
    else
      say "File not found: #{filename}"
    end
  end

  desc "init", "Create a configuration file from template"
  def init
    if File.exist?(".babelish")
      say "Config file '.babelish' already exists."
    else
      say "Creating new config file '.babelish'."
      config_file = File.expand_path("../../../.babelish.sample", __FILE__)
      if File.exist?(config_file)
        system "cp #{config_file} .babelish"
      else
        say "Template '#{config_file}' not found."
      end
    end
  end


  desc "version", "Display current version"
  def version
    require "babelish/version"
    say "Babelish #{Babelish::VERSION}"
  end

  no_tasks do
    def csv2base(classname)
      args = options.dup
      files = [options[:filename]]
      args.delete(:langs)
      args.delete(:filename)

      xcode_macros = Babelish::XcodeMacros.new if options[:macros_filename]
      files.each_with_index do |filename, index|
        if options[:output_basenames]
          args[:output_basename] = options[:output_basenames][index]
        end

        class_object = eval "Babelish::#{classname}"
        args = Thor::CoreExt::HashWithIndifferentAccess.new(args)
        converter = class_object.new(filename, options[:langs], args)
        say converter.convert
        xcode_macros.process(converter.table, converter.keys, converter.comments) if options[:macros_filename]
      end
      if options[:macros_filename]
        say "generating macros"
        xcode_macros.write_content(options[:macros_filename])
      end
    end

    def base2csv(classname)
      class_object = eval "Babelish::#{classname}"
      converter = class_object.new(options)

      debug_values = converter.convert(!options[:dryrun])
      say debug_values.inspect if options[:dryrun]
    end
  end

  def self.exit_on_failure?
    true
  end

  private

  def options
    original_options = super
    return original_options unless File.exist?(original_options["config"])
    defaults = ::YAML.load_file(original_options["config"]) || {}
    Thor::CoreExt::HashWithIndifferentAccess.new(defaults.merge(original_options))
  end
end

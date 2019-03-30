#!/usr/bin/env ruby
require 'pubannotation_evaluator'
require 'json'

rdir = nil

## command line option processing
require 'optparse'
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: pubannotation-eval.rb [options] annotation_file(s)"

  opts.on('-r', '--rdir=directory', 'specifies the path to the directory of reference annotation_file(s).') do |dir|
    rdir = dir

  end

  opts.on('-h', '--help', 'displays this screen.') do
    puts opts
    exit
  end
end

optparse.parse!

if ARGV.length == 0 || rdir.nil?
	puts optparse.help
	exit
end

evaluator = PubannotationEvaluator.new

comparison = ARGV.inject([]) do |col, filepath|
	if File.extname(filepath) == '.json'
		begin
			study_annotations = JSON.parse File.read(filepath), :symbolize_names => true
		rescue
			raise IOError, "Invalid JSON file: #{filepath}"
		end

		filename = File.basename(filepath)
		ref_filepath = File.expand_path(filename, rdir)
		raise IOError, "cannot find the reference file: #{ref_filepath}" unless File.exist?(ref_filepath)
		begin
			reference_annotations = JSON.parse File.read(ref_filepath), :symbolize_names => true
		rescue
			raise IOError, "Invalid JSON file: #{filepath}"
		end

		col += evaluator.compare(study_annotations, reference_annotations)
	end
	col
end

evaluation = evaluator.evaluate(comparison)

false_positives = comparison.select{|m| m[:study] && m[:reference].nil?}
false_negatives = comparison.select{|m| m[:study].nil? && m[:reference]}
puts JSON.generate(evaluation.merge(false_positives:false_positives, false_negatives:false_negatives))
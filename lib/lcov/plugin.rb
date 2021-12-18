# frozen_string_literal: false

# require "lcov_parser"

module Danger
  # This is your plugin class. Any attributes or methods you expose here will
  # be available from within your Dangerfile.
  #
  # To be published on the Danger plugins site, you will need to have
  # the public interface documented. Danger uses [YARD](http://yardoc.org/)
  # for generating documentation from your plugin source, and you can verify
  # by running `danger plugins lint` or `bundle exec rake spec`.
  #
  # You should replace these comments with a public description of your library.
  #
  # @example Ensure people are well warned about merging on Mondays
  #
  #          my_plugin.warn_on_mondays
  #
  # @see  Praveen Vijayan/danger-lcov
  # @tags monday, weekends, time, rattata
  #
  LcovViolation = Struct.new(:coverage, :file)
  $lcov_total_coverage = ""

  class DangerLcov < Plugin
    # An attribute that you can read/write from your Dangerfile
    #
    # @return   [Array<String>]

    # Enable only_modified_files
    # Only show messages within changed files.
    attr_accessor :only_modified_files

    # Report path
    # You should set output from `flutter analyze` here
    attr_accessor :report_path
    # A method that you can call from your Dangerfile
    # @return   [Array<String>]
    #

    def start(inline_mode: false)
      if flutter_exists?
        lint_if_report_exists(inline_mode: inline_mode)
      else
        fail("Could not find `flutter` inside current directory")
      end
    end

    private

    def lint_if_report_exists(inline_mode:)
      if !report_path.nil? && File.exist?(report_path)
        report = File.open(report_path)
        violations = fnviolations(report)
        lint_mode(inline_mode: inline_mode, violations: violations)
      else
        fail("Could not run lint without setting report path or report file doesn't exists")
      end
    end

    def lint_mode(inline_mode:, violations:)
      if inline_mode
        send_inline_comments(violations)
      else
        markdown(summary_table(violations))
      end
    end

    def send_inline_comments(violations)
      filtered_violations = filtered_violations(violations)

      filtered_violations.each do |violation|
        send("warn", violation.description, file: violation.file, line: violation.line)
      end
    end

    def summary_table(violations)
      filtered_violations = filtered_violations(violations)

      if filtered_violations.empty?
        return "### Code Coverage #{filtered_violations.length} issues ✅"
      else
        return markdown_table(filtered_violations)
      end
    end

    def markdown_table(violations)
      table = "### #{$lcov_total_coverage} 👓 \n\n"
      table << "### Files found #{violations.length} \n\n"
      table << "| Coverage | File |\n"
      table << "| -------- | ---- |\n"

      return violations.reduce(table) { |acc, violation| acc << table_row(violation) }
    end

    def table_row(violation)
      "| #{violation.coverage} | `#{violation.file}` |\n"
    end

    def filtered_violations(violations)
      target_files = (git.modified_files - git.deleted_files) + git.added_files
      filtered_violations = violations.select { |violation| target_files.include? violation.file }

      return only_modified_files ? filtered_violations : violations
    end

    def fnviolations(input)
      filtered_input = filter_input(input)
      # puts filtered_input
      return [] if filtered_input.detect { |element| element.include? "No issues found!" }

      get_total_coverrage(filtered_input)

      filtered_input
        .select { |line| line.start_with?(/\d/) }
        .map(&method(:parse_line))
    end

    def get_total_coverrage(input)
        input
        .select { |line| line.start_with? "Total Coverage" }
        .map(&method(:parse_total))
    end

    def filter_input(input)
      input.each_line
        .map(&:strip)
        .reject(&:empty?)
    end

    def parse_line(line)
      # puts line
      coverage, description, file_with_line_number, rule = line.split(" ")
      _,file_name = line.split(/([\w . \/_-]*.dart)/)
      # puts file_name
      LcovViolation.new(coverage, file_name)
    end

    def parse_total(line)
      $lcov_total_coverage = line
      # # puts line
      # coverage, description, file_with_line_number, rule = line.split(" ")
      # _,file_name = line.split(/([\w . \/_-]*.dart)/)
      # # puts file_name
      # LcovViolation.new(coverage, file_name)
    end

    def flutter_exists?
      `which flutter`.strip.empty? == false
    end
    
  end
end

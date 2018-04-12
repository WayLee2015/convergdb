require 'simplecov'
SimpleCov.start if ENV["COVERAGE"]

# required for testing
require 'minitest'
require 'minitest/autorun'

require_relative '../lib/generators/html_doc/html_doc.rb'
require_relative 'helpers/dsd_ddd_ir/test_dsd_ddd_irs.rb'

module ConvergDB
  module Generators
    class TestHtmlDoc < Minitest::Test
      # create a HtmlDoc generator object
      def htmldoc_generator
        HtmlDoc.new(
          TestIR.dsd_ddd_test_02,
          ConvergDB::Deployment::TerraformBuilder.new
        )
      end

      # test the erb path
      def test_erb_path
        src_path = htmldoc_generator.erb_path
        des_path = /[\S]*\/html_doc.erb/
        is_match =  des_path =~ src_path
        assert_equal(is_match.nil?, false)
      end

      # check two files contents are same or not
      def file_contents_match?(file1, file2)
        File.read(file1) == File.read(file2)
      end

      # test erb output
      def test_erb_output
        FileUtils.rm(test_path) rescue nil
        h = htmldoc_generator
        test_path = '/tmp/des.html'

        File.open(test_path, 'w') do |f|
          f.puts htmldoc_generator.erb_output
        end

        assert_equal(
          file_contents_match?(
            "#{File.dirname(__FILE__)}/fixtures/htmldoc/test.html",
            test_path
          ),
          true
        )
      ensure
        FileUtils.rm(test_path) rescue nil
      end

      # test the generated doc file path
      def test_doc_file_path
        src_path = htmldoc_generator.doc_file_path
        des_path = './/docs/production.test_database.test_schema.books_target.html'
        assert_equal(
          src_path,
          des_path
        )
      end

      # test generate html doc
      def test_generate!
        # no test because it is so much state change.
        # all functions and state changing methods in generate!
        # are tested elsewhere
      end
    end
  end
end

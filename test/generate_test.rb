require 'simplecov'
SimpleCov.start if ENV["COVERAGE"]

# required for testing
require 'minitest'
require 'minitest/autorun'
require 'pp'
require 'fileutils'

# imports the ruby file we are testing
require_relative '../lib/generators/generate.rb'
require_relative 'helpers/dsd_ddd_ir/test_dsd_ddd_irs.rb'

module ConvergDB
  module Generators
    class TestBaseGenerator < Minitest::Test
      def base_generator
        ConvergDB::Generators::BaseGenerator.new(
          {},
          ConvergDB::Deployment::TerraformBuilder.new,
          nil
        )
      end

      def test_initialize
        g = base_generator

        assert_equal(
          ConvergDB::Generators::BaseGenerator,
          g.class
        )

        assert_equal(
          {},
          g.structure
        )

        assert_equal(
          ConvergDB::Deployment::TerraformBuilder,
          g.terraform_builder.class
        )
      end

      def test_post_initialize
        # does nothing unless you override it
      end

      def test_generate!
        # raises error unless you override
        x = nil
        begin
          g = base_generator
          g.generate!
        rescue => e
          x = e
        end

        assert_equal(
          true,
          x.is_a?(Exception)
        )
      end

      def test_create_dirs_and_open_file
        g = base_generator

        path = '/tmp/convergdb_test/test_create_dirs_and_open_file/dumb.txt'

        f = g.create_dirs_and_open_file(path, 'w')
        f.print('test')
        f.close

        assert_equal(
          'test',
          File.read(path)
        )
      ensure
        FileUtils.rm_rf(File.dirname(path))
      end
    end

    class TestMasterGenerator < Minitest::Test
      def test_dir
        File.dirname(File.expand_path(__FILE__))
      end

      def primary_ir_structure
        tmp = JSON.parse(
          File.read(
            "#{test_dir}/fixtures/primary_ir/ir.json"
          ),
          :symbolize_names => true
        )
        h = {}
        tmp.each_key { |k| h[k.to_s] = tmp[k] }
        h
      end

      def master_generator
        t = ConvergDB::Generators::MasterGenerator.new(
          primary_ir_structure
        )
        t.aws_clients = nil
        t
      end

      def generators
        m = master_generator
        m.create_generators(m.structure)
      end

      def comparable_etl_glue_jobs
        [
          "nightly_batch"
        ]
      end

      def comparable_athena_relations
        JSON.parse(
          File.read(
            "#{test_dir}/fixtures/primary_ir/comparable_athena_relations.json"
          )
        )
      end

      def test_initialize
        m = master_generator

        assert_equal(
          primary_ir_structure,
          m.structure
        )

        assert_equal(
          [],
          m.generators
        )

        assert_equal(
          ConvergDB::Deployment::TerraformBuilder,
          m.terraform_builder.class
        )
      end

      def test_create_generators
        m = master_generator

        # checks to see if each element of the array is derived from the
        # generator base class. we will leave the details to
        # the tests for the concrete classes.
        m.create_generators(m.structure).each do |g|
          assert_equal(
            true,
            g.is_a?(ConvergDB::Generators::BaseGenerator)
          )
        end

        assert_equal(
          [
            ConvergDB::Generators::StreamingInventoryTableGenerator,
            ConvergDB::Generators::AWSS3Source,
            ConvergDB::Generators::MarkdownDoc,
            ConvergDB::Generators::HtmlDoc,
            ConvergDB::Generators::AWSAthena,
            ConvergDB::Generators::AWSGlue,
            ConvergDB::Generators::AWSFargate,
            ConvergDB::Generators::MarkdownDoc,
            ConvergDB::Generators::HtmlDoc,
            ConvergDB::Generators::AWSAthenaControlTableGenerator
          ],
          generators.map(&:class)
        )
      end

      def test_generate!

      end

      def test_working_path
        m = master_generator

        assert_equal(
          '/tmp',
          m.working_path(m.structure),
          puts(m.working_path(m.structure))
        )
      end

      def test_terraform_directory_path
        m = master_generator

        assert_equal(
          '/tmp/terraform',
          m.terraform_directory_path('/tmp')
        )
      end

      def test_create_static_artifacts!

      end

      def test_create_bootstrap_artifacts!
        m = master_generator

        working_path = '/tmp/convergdb_test'

        FileUtils.mkdir_p(working_path)
        m.create_bootstrap_artifacts!(working_path)

        assert_equal(
          true,
          File.exist?("#{working_path}/bootstrap/bootstrap.tf")
        )
      ensure
        # not safe enough?
        FileUtils.rm_rf(working_path) unless working_path.nil?
      end

      def test_output_diff_messages
        # not testable because it is based around a print()
        # refer to test_current_deployment_athena_relations and
        # test_relation_diff_message
      end
      
      def test_output_athena_relation_diff_message
        # not testable because it is based around a print()
        # refer to test_current_deployment_athena_relations 
      end
      
      def test_current_deployment_athena_relations
        m = master_generator
        g = m.create_generators(m.structure)
        t = m.current_deployment_athena_relations(
          g
        )

        assert_equal(
          [
            "production__ecommerce__inventory.books"
          ],
          t
        )
      end

      def test_output_glue_etl_job_diff_message
        # can not be tested due to print() nature of the method.
        # see test_glue_etl_job_diff_message
      end
    end
  end
end

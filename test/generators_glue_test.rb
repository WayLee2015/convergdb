require 'simplecov'
SimpleCov.start if ENV["COVERAGE"]

# required for testing
require 'minitest'
require 'minitest/autorun'

# imports the ruby file we are testing
require_relative '../lib/generators/generate.rb'
require_relative '../lib/generators/glue/glue.rb'
require_relative 'helpers/dsd_ddd_ir/test_dsd_ddd_irs.rb'

module ConvergDB
  module Generators
    class TestAWSGlue < Minitest::Test
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

      def glue_friendly_structure
        primary_ir = primary_ir_structure
        return primary_ir["production.ecommerce.inventory.books"]
      end

      def glue_generator(working_path = nil)
        # allow for optional working path for use
        # in artifact creation tests
        test_ir = glue_friendly_structure
        test_ir[:working_path] = working_path if working_path
        AWSGlue.new(
          test_ir,
          ConvergDB::Deployment::TerraformBuilder.new,
          nil
        )
      end

      #! DIFF METHOD TESTING
      
      def get_job_response
        {:job=>
          {:name=>"demo_ad_tech_etl_job",
           :role=>"convergdb-demo_ad_tech_etl_job-2760114836018639773",
           :created_on=>'2018-03-27 12:19:02 -0700',
           :last_modified_on=>'2018-06-21 09:56:35 -0700',
           :execution_property=>{:max_concurrent_runs=>1},
           :command=>
            {:name=>"glueetl",
             :script_location=>
              "s3://convergdb-admin-9083c59b16173549/9083c59b16173549/scripts/aws_glue/demo_ad_tech_etl_job/demo_ad_tech_etl_job.py"},
           :default_arguments=>
            {"--conf"=>"spark.yarn.executor.memoryOverhead=1024",
             "--convergdb_deployment_id"=>"9083c59b16173549",
             "--extra-py-files"=>
              "s3://convergdb-admin-9083c59b16173549/9083c59b16173549/scripts/aws_glue/demo_ad_tech_etl_job/convergdb.zip"},
           :connections=>{},
           :max_retries=>0,
           :allocated_capacity=>2}}
      end
      
      def get_trigger_response
        {:trigger=>
          {:name=>"convergdb-demo_ad_tech_etl_job",
           :type=>"SCHEDULED",
           :state=>"CREATED",
           :schedule=>"cron(0 0 * * ? *)",
           :actions=>[{:job_name=>"demo_ad_tech_etl_job"}]}}
      end
      
      def test_comparable_glue_structure
        g = glue_generator
        expected = {
          dpu: 2,
          etl_job_schedule: 'cron(0 0 * * ? *)'
        }
        assert_equal(
          expected,
          g.comparable_glue_structure(
            get_job_response,
            get_trigger_response
          )
        )
      end
      
      def test_generate!
        # no test because it is so much state change.
        # all functions and state changing methods in generate!
        # are tested elsewhere
      end

      def test_glue_etl_job_module_params
        g = glue_generator

        expected = {
          resource_id: "aws_glue_nightly_batch",
          region: "${var.region}",
          job_name: 'nightly_batch',
          local_script: g.etl_job_script_relative_path(g.structure),
          local_pyspark_library: g.pyspark_library_relative_path(g.structure),
          script_bucket: 'demo-utility-us-east-2.beyondsoft.us',
          script_key: g.pyspark_script_key(g.structure),
          pyspark_library_key: g.pyspark_library_key(g.structure),
          schedule: 'cron(0 0 * * ? *)',
          dpu: 2,
          stack_name: g.terraform_builder.to_dash(
            "convergdb-glue-nightly_batch"
          ) + '-${var.deployment_id}',
          service_role: "glueService"
        }

        assert_equal(
          expected,
          g.glue_etl_job_module_params(g.structure)
        )
      end

      def file_contents_match?(file1, file2)
        File.read(file1) == File.read(file2)
      end

      def test_create_static_artifacts!
        test_working_path = '/tmp/convergdb_glue_generator_test/'
        g = glue_generator(test_working_path)

        # FileUtils.mkdir_p(test_working_path)

        g.create_static_artifacts!(g.structure)
        
        assert(
          file_contents_match?(
            "#{File.dirname(__FILE__)}/../lib/generators/convergdb.zip",
            "#{test_working_path}/terraform/aws_glue/convergdb.zip"
          )
        )
      ensure
        FileUtils.rm_r(test_working_path) rescue nil
      end

      def test_tf_glue_path
        g = glue_generator

        assert_equal(
          "/tmp/terraform/aws_glue",
          g.tf_glue_path(g.structure)
        )
      end

      def test_tf_glue_relative_path
        g = glue_generator

        assert_equal(
          "./aws_glue",
          g.tf_glue_relative_path
        )
      end
      
      def test_etl_job_script_path
        g = glue_generator

        assert_equal(
          "#{g.tf_glue_path(g.structure)}/nightly_batch.py",
          g.etl_job_script_path(g.structure)
        )
      end

      def test_etl_job_script_relative_path
        g = glue_generator

        assert_equal(
          "#{g.tf_glue_relative_path}/nightly_batch.py",
          g.etl_job_script_relative_path(g.structure)
        )
      end
      
      def test_pyspark_library_path
        g = glue_generator

        assert_equal(
          "#{g.tf_glue_path(g.structure)}/convergdb.zip",
          g.pyspark_library_path(g.structure)
        )
      end

      def test_pyspark_library_relative_path
        g = glue_generator

        assert_equal(
          "#{g.tf_glue_relative_path}/convergdb.zip",
          g.pyspark_library_relative_path(g.structure)
        )
      end
      
      def test_create_etl_script_if_not_exists!
        FileUtils.rm(test_path) rescue nil
        g = glue_generator
        test_path = '/tmp/test_etl_script.py'
        g.create_etl_script_if_not_exists!(test_path)

        assert(File.exist?(test_path))

        assert_equal(
          %{import os
import sys
from awsglue.utils import getResolvedOptions
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'convergdb_lock_table','aws_region'])
os.environ['AWS_GLUE_REGION'] = args['aws_region']
os.environ['LOCK_TABLE'] = args['convergdb_lock_table']
os.environ['LOCK_ID']    = args['JOB_NAME']
import convergdb
from convergdb.glue_header import *\n\n},
          File.read(test_path)
        )
      ensure
        FileUtils.rm(test_path) rescue nil
      end

      def test_append_to_job_script!
        FileUtils.rm(test_path) rescue nil
        g = glue_generator
        test_path = '/tmp/test_etl_script.py'
        g.create_etl_script_if_not_exists!(test_path)
        g.append_to_job_script!(
          test_path,
          'test append'
        )

        assert_equal(
          %{import os
import sys
from awsglue.utils import getResolvedOptions
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'convergdb_lock_table','aws_region'])
os.environ['AWS_GLUE_REGION'] = args['aws_region']
os.environ['LOCK_TABLE'] = args['convergdb_lock_table']
os.environ['LOCK_ID']    = args['JOB_NAME']
import convergdb
from convergdb.glue_header import *\n\ntest append\n\n},
          File.read(test_path)
        )
      ensure
        FileUtils.rm(test_path) rescue nil
      end

      def test_pyspark_cast_type
        g = glue_generator

        [
          { sql: 'varchar(100)', pyspark: 'string' },
          { sql: 'char(32)', pyspark: 'string' },
          { sql: 'decimal(20,3)', pyspark: 'decimal(20,3)' },
          { sql: 'numeric(20,3)', pyspark: 'decimal(20,3)' },
        ].each do |t|
          assert_equal(
            t[:pyspark],
            g.pyspark_cast_type(t[:sql])
          )
        end
      end
      
      def test_deployment_id
        g = glue_generator
        
        assert_equal(
          '${var.deployment_id}',
          g.deployment_id
        )
      end
      
      def test_pyspark_s3_key_prefix
        g = glue_generator
        expected = %{#{g.deployment_id}/scripts/aws_glue/nightly_batch}
        
        assert_equal(
          expected,
          g.pyspark_s3_key_prefix(g.structure)
        )
      end
      
      def test_pyspark_library_key
        g = glue_generator
        expected = %{#{g.pyspark_s3_key_prefix(g.structure)}/convergdb.zip}

        assert_equal(
          expected,
          g.pyspark_library_key(g.structure)
        )
      end
      
      def test_pyspark_script_key
        g = glue_generator
        expected = %{#{g.pyspark_s3_key_prefix(g.structure)}/nightly_batch.py}
        
        assert_equal(
          expected,
          g.pyspark_script_key(g.structure)
        )
      end
      
      def test_apply_cast_type!
        g = glue_generator
        s = glue_friendly_structure
        
        g.apply_cast_type!(s)
        
        # source
        assert_equal(
          ["integer", "string", "string", "decimal(10,2)", "integer"],
          s[:source_structure][:attributes].map {|a| a[:cast_type] }
        )
        
        # target
        assert_equal(
          ["integer", "string", "string", "decimal(10,2)", "string", "decimal(10,2)"],
          s[:attributes].map {|a| a[:cast_type] }
        )
      end
      
      def test_post_initialize
        g = glue_generator
        
        # insure that deployment_id is defaulted.
        # this value is resolved with a terraform template variable.
        assert_equal(
          '${deployment_id}',
          g.structure[:deployment_id]
        )
        
        # insure that region is defaulted.
        # this value is resolved with a terraform template variable.
        assert_equal(
          '${region}',
          g.structure[:region]
        )
        
        # get a list of all the source attributes with cast type applied
        source = g.structure[:source_structure][:attributes].select do |a|
          a.key?(:cast_type)
        end
        
        # get a list of all the target attributes with cast type applied
        target = g.structure[:attributes].select { |a| a.key?(:cast_type) }
        
        # we are just making sure that every attribute was mutated with the
        # apply_cast_type! method. we aren't testing the method itself so
        # we only need to check for the count of mutated attributes.
        assert_equal(
          5,
          source.length
        )

        assert_equal(
          6,
          target.length
        )
      end
      
      def test_pyspark_source_to_target
        g = glue_generator
        
        assert_equal(
          File.read(
            "#{File.dirname(__FILE__)}/fixtures/glue/pyspark_source_to_target.py"
          ),
          g.pyspark_source_to_target(g.structure),
          #g.pyspark_source_to_target(g.structure)
          pp(g.structure)
        )
      end
    end
  end
end

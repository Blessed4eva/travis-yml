module Travis
  module Yml
    class Matrix
      class Env < Obj.new(:config, :data, :jobs)
        # should be able to drop a lot of this once everyone's on /configs

        def apply
          jobs = with_env_arrays(self.jobs)
          jobs = with_first_env(jobs)
          jobs = with_global_env(jobs)
          jobs = with_filtered_env(jobs)
          jobs
        end

        def with_env_arrays(jobs)
          jobs.each { |job| job[:env] = with_env_array(job[:env]) if job[:env] }
        end

        def with_env_array(env)
          case env
          when Hash  then wrap(except(env, :global)).reject(&:empty?)
          when Array then env.map { |env| with_env_array(env) }.flatten(1)
          else wrap(env)
          end
        end

        def with_global_env(jobs)
          jobs.each { |job| job[:env] = global_env.+(job[:env] || []).uniq } if global_env
          jobs
        end

        # The legacy implementation picked the first env var out of `env.jobs` to
        # jobs listed in `jobs.include` if they do not define a key `env` already.
        def with_first_env(jobs)
          jobs.each { |job| (job[:env] ||= []).concat([first_env]).uniq! unless job[:env] } if first_env
          jobs
        end

        def with_filtered_env(jobs)
          jobs.each { |job| filter_env(job) if job[:env] }
          jobs
        end

        def global_env
          env = config[:env] && config[:env].is_a?(Hash) && config[:env][:global]
          env = env || config[:global_env] # BC Gatekeeper matrix expansion
          env = [env] if env.is_a?(String)
          env
        end

        def first_env
          case env = config[:env]
          when Array
            env.first
          when Hash
            env.fetch(:jobs, nil)&.first
          end
        rescue nil
        end

        def wrap(obj)
          obj.is_a?(Array) ? obj : [obj]
        end

        def filter_env(job)
          job[:env].each do |hash|
            hash.delete(:secure) if hash.key?(:secure) && data.key?(:head_repo) && data[:repo] != data[:head_repo]
          end
        end
      end
    end
  end
end

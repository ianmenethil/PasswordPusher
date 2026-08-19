# frozen_string_literal: true

# Runs the app's recurring maintenance jobs (see config/recurring.yml) from a normal web
# request instead of relying on a dedicated Solid Queue worker process.
#
# This exists because the app is deployed on Render's free tier, which has no background-worker
# plan and spins the web service down after ~15 minutes of inactivity. Solid Queue's own
# in-memory scheduler computes each job's next run from wall-clock "now" at boot
# (solid_queue/scheduler/recurring_schedule.rb), so it silently skips every run missed while the
# process was asleep, with no catch-up. Last-run times are tracked in SiteSetting (already used
# for custom_css) rather than a file, since Render's free-tier disk is ephemeral and wouldn't
# reliably survive a restart.
module RecurringJobRunner
  JOBS = {
    "expire_pushes" => [ExpirePushesJob, 2.hours],
    "cleanup_pushes" => [CleanUpPushesJob, 1.day],
    "purge_expired_pushes" => [PurgeExpiredPushesJob, 1.day],
    "purge_unattached_blobs" => [PurgeUnattachedBlobsJob, 3.days],
    "cleanup_cache" => [CleanupCacheJob, 1.day]
  }.freeze

  class << self
    # Runs any job whose interval has elapsed since it last ran, then records the new run time.
    def run_overdue!
      last_run_by_key = SiteSetting.where(key: settings_keys).index_by(&:key)

      JOBS.each do |name, (job_class, interval)|
        setting = last_run_by_key[settings_key(name)]
        last_run_at = setting && Time.iso8601(setting.value)

        next if last_run_at && last_run_at > interval.ago

        job_class.perform_now
        record_run!(name)
      end
    end

    private

    def settings_keys
      JOBS.keys.map { |name| settings_key(name) }
    end

    def settings_key(name)
      "last_run:#{name}"
    end

    def record_run!(name)
      setting = SiteSetting.find_or_initialize_by(key: settings_key(name))
      setting.value = Time.current.iso8601
      setting.save!
    end
  end
end

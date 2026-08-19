# frozen_string_literal: true

# Rack middleware wrapper for RecurringJobRunner (see app/services/recurring_job_runner.rb).
#
# Runs at the Rack layer, not as a controller callback, so it fires on every request
# regardless of what happens downstream -- including 401s, redirects to sign-in, and any
# before_action that halts the Rails controller callback chain. That halting matters here:
# Rails aborts the *entire* callback chain (including after_action) when an earlier
# before_action renders or redirects, which is exactly what happens on most unauthenticated
# requests -- the very requests most likely to be the one that wakes a sleeping instance.
class RecurringJobCatchupMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    (env["rack.after_reply"] ||= []) << -> { RecurringJobRunner.run_overdue! }
    @app.call(env)
  end
end

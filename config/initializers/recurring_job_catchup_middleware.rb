# frozen_string_literal: true

# Registers RecurringJobCatchupMiddleware. Loaded via plain `require`, not Zeitwerk
# autoloading, because config/initializers/*.rb run before the main autoloader is guaranteed
# ready to resolve a constant from a newly-added app/* directory (app/middleware isn't one of
# Rails' default autoloaded app/* dirs -- see config/application.rb for its registration).
require Rails.root.join("app/middleware/recurring_job_catchup_middleware")

Rails.application.config.middleware.use RecurringJobCatchupMiddleware

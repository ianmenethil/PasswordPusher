get "/admin", to: "admin#index", as: :admin_root

namespace :admin do
  resources :users, only: [:index, :destroy] do
    member do
      patch :promote
      patch :revoke
    end
  end

  resource :custom_css, only: [:edit, :update], controller: "custom_css"
end

# MissionControl::Jobs::Engine has no admin guard of its own, so the routing
# constraint stays here as its only protection (unlike the routes above,
# which are guarded by AdminController#require_admin).
authenticated :user, lambda { |u| u.admin? } do
  mount MissionControl::Jobs::Engine, at: "/admin/jobs" if defined?(::MissionControl::Jobs::Engine)
end

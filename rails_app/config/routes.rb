Rails.application.routes.draw do
  devise_for :players, controllers: { sessions: 'sessions', omniauth_callbacks: 'players/omniauth_callbacks' }
  root 'home#index'
end

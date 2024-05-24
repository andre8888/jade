Rails.application.routes.draw do
  # root 'property#index'
  # get 'calculator/index'

  root 'calculator#index'
  get 'calculator/new', to: 'calculator#new'
  post 'calculator/run', to: 'calculator#run', as: :run_calculator
end

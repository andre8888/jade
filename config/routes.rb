Rails.application.routes.draw do
	root 'property#new'

	get 'property/new', to: 'property#new', as: :new_property
	post 'property/search', to: 'property#search', as: :search_property

	get 'neighborhood/new', to: 'neighborhood#new', as: :new_neighborhood
	post 'neighborhood/search', to: 'neighborhood#search', as: :search_neighborhood
	get 'neighborhood', to: 'neighborhood#index', as: :neighborhood
	get 'neighborhood/search', to: redirect('/neighborhood/new')

	get 'account/edit', to: 'account#edit', as: :edit_account

	get 'support', to: 'support#index', as: :support
end

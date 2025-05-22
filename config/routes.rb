# frozen_string_literal: true

::RemakeLimit::Engine.routes.draw do
  constraints AdminConstraint.new do
    get "/query" => "remake_limit#query"
    delete "/id/:id" => "remake_limit#ignore"
    put "/user/:user_id" => "remake_limit#create_for_user"
    delete "/user/:user_id" => "remake_limit#ignore_for_user"
  end
end

Discourse::Application.routes.draw { mount ::RemakeLimit::Engine, at: "/remake_limit" }

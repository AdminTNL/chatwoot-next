# frozen_string_literal: true

FactoryBot.define do
  factory :label_group do
    account
    team
    sequence(:name) { |n| "Label Group #{n}" }
  end
end

# frozen_string_literal: true

require_relative 'spec_helper'
require_relative 'cnfs/urn'
require 'pry'
require 'tempfile'

# arn:partition:service:region:account-id:resource-type/resource-id
# Policies are attached to a user so assume these policies belong to a user
# So when testing assume it is an API request to do 'action' on a resource
# and we are checking the policies to see if the action is allowed on the requested resource
#             "resource_x": "urn:perx:cognito:ap-southeast-1:123456789:user/*",
describe 'Integration Testing' do
  before(:all) do
    @file = Tempfile.new('policies')
    # user:id must be equal to resource_id
    @file.write <<-USER_POLICY
      [
        { "name": "CognitoPowerUser",
          "description": "Provides administrative access to existing Cognito resources",
          "version": "1",
          "rules": [
            {
              "description": "Allow owners to read their account",
              "resource": "urn:spec:cognito:*:*:user",
              "action": ["cognito:ReadUser"],
              "effect": "allow",
              "conditions": [
                {
                  "equal": {
                    "user::id": ["resource::id"]
                  }
                }
              ]
            }
          ]
        },
        { "name": "StoragePowerUser",
          "description": "Provides administrative access to existing Storage resources",
          "version": "1",
          "rules": [
            {
              "description": "Allow user to read all objects in account",
              "resource": "urn:spec:storage:*:*",
              "action": ["storage:ReadObject"],
              "effect": "allow"
            }
          ]
        }
      ]
    USER_POLICY

    @file_two = Tempfile.new('resource_policy')
    @file_two.write <<-RESOURCE_POLICY
      [
        { "name": "StorageObject",
          "description": "Storage Policy for Bucket and Object",
          "version": "1",
          "rules": [
            {
              "description": "Allow specific users to access object on bucket",
              "resource": "urn:spec:storage:ap-southeast-1:123456789:bucket/object",
              "action": ["storage:ReadObject"],
              "effect": "allow",
              "conditions": [
                {
                  "equal": {
                    "user:id": ["1"]
                  }
                }
              ]
            }
          ]
        }
      ]
    RESOURCE_POLICY
    @file.rewind
    @file_two.rewind
    IronHide.configure do |config|
      # config.adapter   = :cnfs_file
      config.json = @file.path
      # config.namespace = ''
    end
  end

  after(:all) { @file.close }

  class TestUser
    attr_accessor :urn, :id

    def initialize
      @id = 1
      @urn = Cnfs::Urn.from_urn('urn:spec:cognito::123456789:user/1')
      # binding.pry
      # @urn = 'urn:spec:cognito::123456789:user/1'
    end

    def manager
      @manager ||= TestUser.new
    end
  end

  class TestResource
    attr_accessor :active, :urn, :id

    def initialize
      @id = 1
      @urn = Cnfs::Urn.from_urn('urn:spec:cognito::123456789:user/1')
      # @urn = 'urn:spec:storage:ap-southeast-1:123456789:bucket/object_name'
      # @urn = 'urn:spec:cognito::123456789:user/1'
    end
  end

  let(:user)     { TestUser.new }
  let(:resource) { TestResource.new }

  context 'when one rule matches an action' do
    context "when effect is 'allow'" do
      let(:action) { 'cognito:ReadUser' }
      let(:rules)  { IronHide::Rule.find(user, action, resource) }
      specify      { expect(rules.size).to eq 1 }
      specify      { expect(rules.first.effect).to eq 'allow' }

      context 'when all conditions are met' do
        specify { expect(IronHide.can?(user, action, resource)).to be_truthy }
        specify { expect { IronHide.authorize!(user, action, resource) }.to_not raise_error }
      end

      context 'when some conditions are met' do
        before do
          # TODO: Should conditions only ever check against the URN or also to attributes
          # NOTE: If attributes return values from the URN then could query URN but also other attributes
          #       e.g. urn_id returns id from URN rather than calling id itself
          # binding.pry
          user.id = 2
          user.urn = Cnfs::Urn.from_urn('urn:spec:cognito::123456789:user/2')
          # user.urn = user.urn.gsub('/1', '/2')
        end

        specify { expect(IronHide.can?(user, action, resource)).to be_falsey }
        specify { expect { IronHide.authorize!(user, action, resource) }.to raise_error IronHide::AuthorizationError }
      end
    end

    xcontext "when effect is 'deny'" do
      let(:action) { 'disable' }
      let(:rules)  { IronHide::Rule.find(user, action, resource) }
      specify      { expect(rules.size).to eq 1 }
      specify      { expect(rules.first.effect).to eq 'deny' }

      context 'when all conditions are met' do
        before { user.role_ids << 99 }
        specify { expect(IronHide.can?(user, action, resource)).to be_falsey }
        specify { expect { IronHide.authorize!(user, action, resource) }.to raise_error IronHide::AuthorizationError }
      end

      context 'when no conditions are met' do
        specify { expect(IronHide.can?(user, action, resource)).to be_falsey }
        specify { expect { IronHide.authorize!(user, action, resource) }.to raise_error IronHide::AuthorizationError }
      end
    end
  end

  xcontext 'when no rule matches an action' do
    let(:action) { 'some-crazy-rule' }
    let(:rules)  { IronHide::Rule.find(user, action, resource) }
    specify      { expect(rules.size).to eq 0 }
    specify { expect(IronHide.can?(user, action, resource)).to be_falsey }
    specify { expect { IronHide.authorize!(user, action, resource) }.to raise_error IronHide::AuthorizationError }
  end

  xcontext 'when multiple rules match an action' do
    let(:action) { 'read' }
    let(:rules)  { IronHide::Rule.find(user, action, resource) }
    specify      { expect(rules.size).to eq 3 }

    context 'when conditions for only one rule are met' do
      context "when effect is 'allow'" do
        before  { user.role_ids << 5 }
        specify { expect(IronHide.can?(user, action, resource)).to be_truthy }
        specify { expect { IronHide.authorize!(user, action, resource) }.to_not raise_error }
      end

      context "when effect is 'deny'" do
        before { resource.active = false }
        specify { expect(IronHide.can?(user, action, resource)).to be_falsey }
        specify { expect { IronHide.authorize!(user, action, resource) }.to raise_error IronHide::AuthorizationError }
      end
    end

    context 'when conditions for all rules are met' do
      context "when at least one rule's effect is 'deny'" do
        before  do
          resource.active = false
          user.name = 'Cyril Figgis'
          user.role_ids << 5
        end

        specify { expect(IronHide.can?(user, action, resource)).to be_falsey }
        specify { expect { IronHide.authorize!(user, action, resource) }.to raise_error IronHide::AuthorizationError }
      end
    end
  end

  xdescribe 'testing rule with multiple conditions' do
    let(:action) { 'destroy' }
    let(:rules)  { IronHide::Rule.find(user, action, resource) }
    specify      { expect(rules.size).to eq 1 }
    context 'when only one condition is met' do
      before  { resource.active = false; user.role_ids << 954 }
      specify { expect(IronHide.can?(user, action, resource)).to be_falsey }
      specify { expect { IronHide.authorize!(user, action, resource) }.to raise_error IronHide::AuthorizationError }
    end

    context 'when all conditions are met' do
      before  { resource.active = false; user.role_ids << 25 }
      specify { expect(IronHide.can?(user, action, resource)).to be_truthy }
      specify { expect { IronHide.authorize!(user, action, resource) }.to_not raise_error }
    end
  end

  xdescribe 'testing rule with nested attributes' do
    let(:action) { 'fire' }
    let(:rules)  { IronHide::Rule.find(user, action, resource) }
    context 'when conditions are met' do
      before  { user.manager.name = 'Lumbergh' }
      specify { expect(IronHide.can?(user, action, resource)).to be_truthy }
      specify { expect { IronHide.authorize!(user, action, resource) }.to_not raise_error }
    end
    context 'when conditions are not met' do
      before  { user.manager.name = 'Phil' }
      specify { expect(IronHide.can?(user, action, resource)).to be_falsey }
      specify { expect { IronHide.authorize!(user, action, resource) }.to raise_error IronHide::AuthorizationError }
    end
  end
end

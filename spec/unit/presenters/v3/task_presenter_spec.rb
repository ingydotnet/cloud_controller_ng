require 'spec_helper'
require 'presenters/v3/task_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe TaskPresenter do
    subject(:presenter) { TaskPresenter.new(task) }
    let(:task) {
      VCAP::CloudController::TaskModel.make(
        environment_variables: { 'some' => 'stuff' },
        failure_reason:        'sup dawg',
        memory_in_mb:          2048,
        updated_at:            Time.at(2),
        created_at:            Time.at(1),
        sequence_id:           5
      )
    }
    let(:scheme) { TestConfig.config[:external_protocol] }
    let(:host) { TestConfig.config[:external_domain] }
    let(:link_prefix) { "#{scheme}://#{host}" }

    describe '#to_hash' do
      let(:result) { presenter.to_hash }

      it 'presents the task as a hash' do
        links = {
          self:    { href: "#{link_prefix}/v3/tasks/#{task.guid}" },
          app:     { href: "#{link_prefix}/v3/apps/#{task.app.guid}" },
          droplet: { href: "#{link_prefix}/v3/droplets/#{task.droplet.guid}" },
        }

        expect(result[:guid]).to eq(task.guid)
        expect(result[:name]).to eq(task.name)
        expect(result[:command]).to eq(task.command)
        expect(result[:state]).to eq(task.state)
        expect(result[:result][:failure_reason]).to eq 'sup dawg'
        expect(result[:environment_variables]).to eq(task.environment_variables)
        expect(result[:memory_in_mb]).to eq(task.memory_in_mb)
        expect(result[:sequence_id]).to eq(5)
        expect(result[:created_at]).to eq(task.created_at.iso8601)
        expect(result[:updated_at]).to eq(task.updated_at.iso8601)
        expect(result[:links]).to eq(links)
      end

      context 'when show_secrets is false' do
        let(:presenter) { TaskPresenter.new(task, show_secrets: false) }

        it 'excludes command and environment_variables' do
          expect(result).not_to have_key(:command)
          expect(result).not_to have_key(:environment_variables)
        end
      end
    end
  end
end

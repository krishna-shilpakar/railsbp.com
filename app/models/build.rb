class Build < ActiveRecord::Base
  include AASM

  belongs_to :repository

  after_create :analyze

  aasm do
    state :scheduled, :initial => true
    state :running
    state :completed

    event :run do
      transitions :to => :running, :from => [:scheduled, :running]
    end

    event :complete do
      transitions :to => :completed, :from => :running
    end
  end

  def analyze
    run!
    absolute_path = Rails.root.join("builds", repository.unique_name, "commit", last_commit_id).to_s
    clone_url = repository.private? ? repository.ssh_url : repository.git_url
    FileUtils.mkdir_p(absolute_path) unless File.exist?(absolute_path)
    Git.clone(clone_url, :name => repository.name, :path => absolute_path)
    rails_best_practices = RailsBestPractices::Analyzer.new(absolute_path)
    rails_best_practices.analyze
    rails_best_practices.output
    complete!
  end
  handle_asynchronously :analyze
end

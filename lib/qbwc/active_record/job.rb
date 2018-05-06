class QBWC::ActiveRecord::Job < QBWC::Job
  class QbwcJob < ActiveRecord::Base
    validates :name, :uniqueness => true, :presence => true
    serialize :requests, Hash
    serialize :request_index, Hash
    serialize :data

    def to_qbwc_job
      QBWC::ActiveRecord::Job.new(name, enabled, company, account_id, worker_class, requests, data, self)
    end

  end

  # Creates and persists a job.
  def self.add_job(name, enabled, company, account_id, worker_class, requests, data)
    worker_class = worker_class.to_s
    ar_job = find_ar_job_with_name(name).first_or_initialize
    ar_job.company = company
    ar_job.account_id = account_id
    ar_job.enabled = enabled
    ar_job.worker_class = worker_class
    ar_job.save!

    jb = self.new(name, enabled, company, account_id, worker_class, requests, data, ar_job)
    unless requests.nil? || requests.empty?
      request_hash = { [nil, company] => [requests].flatten }

      jb.requests = request_hash
      ar_job.update_attribute :requests, request_hash
    end
    jb.requests_provided_when_job_added = (! requests.nil? && ! requests.empty?)
    jb.data = data
    jb
  end

  def self.find_job_with_name(name)
    j = find_ar_job_with_name(name).first
    j = j.to_qbwc_job unless j.nil?
    return j
  end

  def self.find_ar_job_with_name(name)
    QbwcJob.where(:name => name)
  end

  def find_ar_job
    if self.storage_job
      return self.storage_job
    else
      self.class.find_ar_job_with_name(name).first
    end
  end

  def self.delete_job_with_name(name)
    j = find_ar_job_with_name(name).first
    j.destroy unless j.nil?
  end

  def enabled=(value)
    find_ar_job.update(:enabled => value)
  end

  def enabled?
    true
  end

  def requests(session = QBWC::Session.get)
    @requests = find_ar_job.requests
    super
  end

  def set_requests(session, requests)
    super
    find_ar_job.update(:requests => @requests)
  end

  def requests_provided_when_job_added
    find_ar_job.requests_provided_when_job_added
  end

  def requests_provided_when_job_added=(value)
    find_ar_job.update(:requests_provided_when_job_added => value)
    super
  end

  def data
    find_ar_job.data
  end

  def data=(r)
    find_ar_job.data = save
    find_ar_job.save 
    super
  end

  def request_index(session)
    (find_ar_job.request_index || {})[session.key] || 0
  end

  def set_request_index(session, index)
    jb = find_ar_job
    jb.request_index[session.key] = index
    jb.save
  end

  def advance_next_request(session)
    nr = request_index(session)
    set_request_index session, nr + 1
  end

  def reset
    super
    job = find_ar_job
    job.update :request_index => {}
    job.update(:requests => {}) unless self.requests_provided_when_job_added
  end

  def self.list_jobs(account_id = nil)
    if account_id
      jobs = QbwcJob.where(account_id: account_id)
    else
      jobs = QbwcJob.all
    end
    jobs.map {|ar_job| ar_job.to_qbwc_job}
  end

  def self.get_jobs_by_names(job_names, account_id)
    jobs = QbwcJob.where(name: job_names)

    if account_id
      jobs = jobs.where(account_id: account_id)
    end

    jobs.map {|ar_job| ar_job.to_qbwc_job}
  end

  def self.clear_jobs
    QbwcJob.delete_all
  end

  def self.sort_in_time_order(ary)
    ary.sort {|a,b| a.find_ar_job.created_at <=> b.find_ar_job.created_at}
  end

end

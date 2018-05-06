class QBWC::ActiveRecord::Session < QBWC::Session
  class QbwcSession < ActiveRecord::Base
    attr_accessible :company, :ticket, :user, :account_id unless Rails::VERSION::MAJOR >= 4
  end

	def self.get(ticket)
		session = QbwcSession.find_by_ticket(ticket)
    self.new(session) if session
	end

  def initialize(session_or_user = nil, company = nil, ticket = nil, account_id = nil)
    if session_or_user.is_a? QbwcSession
      @session = session_or_user
      # Restore current job from saved one on QbwcSession
      @current_job = QBWC.get_job(@session.current_job) if @session.current_job
      # Restore pending jobs from saved list on QbwcSession
      @pending_jobs = refresh_pending_jobs(@session.pending_jobs.split(','), account_id, self)
      super(@session.user, @session.company, @session.ticket, @session.account_id)
    else
      super
      @session = QbwcSession.new
      @session.user = self.user
      @session.company = self.company
      @session.ticket = self.ticket
      @session.account_id = self.account_id
      self.save
      @session
    end
  end

  def refresh_pending_jobs(pending_job_names, account_id, session)
    QBWC.get_pending_jobs_by_name(@session.pending_jobs, account_id, self)
  end

  def save
    @session.pending_jobs = refresh_pending_jobs(pending_jobs.map(&:name), nil, self)
    @session.current_job = current_job.try(:name)
    @session.save
    super
  end

  def destroy
    @session.destroy
    super
  end

  [:error, :progress, :iterator_id].each do |method|
    define_method method do
      @session.send(method)
    end
    define_method "#{method}=" do |value|
      @session.send("#{method}=", value)
    end
  end
  protected :progress=, :iterator_id=, :iterator_id

end

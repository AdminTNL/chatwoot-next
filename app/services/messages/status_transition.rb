class Messages::StatusTransition
  PROGRESS_LADDER = %w[sent delivered read].freeze

  def self.allowed?(from:, to:)
    from = from.presence&.to_s
    to = to.to_s
    return false unless Message.statuses.key?(to)
    return true if from.nil? || from == to
    return from == 'sent' if to == 'failed'
    return false if from == 'failed'

    PROGRESS_LADDER.index(to) > PROGRESS_LADDER.index(from)
  end
end

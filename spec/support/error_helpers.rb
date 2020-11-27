module ErrorHelpers
  def ignore_errors
    yield
  rescue StandardError => e
    Mongoid.logger.debug "ignored error #{e}"
  end
end

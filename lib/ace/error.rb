# frozen_string_literal: true

module ACE
  class Error < RuntimeError
    attr_reader :kind, :details, :issue_code, :error_code

    def initialize(msg, kind, details = nil, issue_code = nil)
      super(msg)
      @kind = kind
      @issue_code = issue_code
      @details = details || {}
      @error_code ||= 1
    end

    def msg
      message
    end

    def to_h
      Error.to_h(msg, kind, details, issue_code)
    end

    def to_json(opts = nil)
      to_h.to_json(opts)
    end

    def self.to_h(message, kind, details = nil, issue_code = nil)
      h = { 'kind' => kind,
            'msg' => message,
            'details' => details }
      h['issue_code'] = issue_code if issue_code
      h
    end
  end
end

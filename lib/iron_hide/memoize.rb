# frozen_string_literal: true

module IronHide
  # The SimpleCache does not expire cache entries
  # It is used only to memoize method calls during a single authorization
  # decision.
  #
  class SimpleCache
    attr_accessor :cache

    def initialize
      @cache = {}
    end

    def fetch(expression)
      cache.fetch(expression) do
        cache[expression] = yield
      end
    end
  end

  class NullCache
    def fetch(_)
      yield
    end
  end
end

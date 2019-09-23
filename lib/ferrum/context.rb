# frozen_string_literal: true

require "ferrum/target"

module Ferrum
  class Context
    attr_reader :id, :targets

    def initialize(browser, contexts, id)
      @browser, @contexts, @id = browser, contexts, id
      @targets = Concurrent::Hash.new
      @pendings = Concurrent::MVar.new
    end

    def default_target
      @default_target ||= create_target
    end

    def page
      default_target.page
    end

    def pages
      @targets.values.map(&:page)
    end

    def windows
      @targets.values.select(&:window?).map(&:page)
    end

    # When we call `page` method on target it triggers ruby to connect to given
    # page by WebSocket, if there are many opened windows but we need only one
    # it makes more sense to get and connect to the needed one only which
    # usually is the last one.
    def last_window
      @targets.values.select(&:window?).last&.page
    end

    def create_page
      create_target.page
    end

    def create_target
      target_id = @browser.command("Target.createTarget",
                                   browserContextId: @id,
                                   url: "about:blank")["targetId"]
      target = @pendings.take(@browser.timeout)
      raise NoSuchTargetError unless target.is_a?(Target)
      @targets[target.id] = target
      target
    end

    def add_target(params)
      target = Target.new(@browser, params)
      if target.window?
        @targets[target.id] = target
      else
        @pendings.put(target, @browser.timeout)
      end
    end

    def update_target(target_id, params)
      @targets[target_id].update(params)
    end

    def delete_target(target_id)
      @targets.delete(target_id)
    end

    def dispose
      @contexts.dispose(@id)
    end

    def inspect
      %(#<#{self.class} @id=#{@id.inspect} @targets=#{@targets.inspect} @default_target=#{@default_target.inspect}>)
    end
  end
end

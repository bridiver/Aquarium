#!/usr/bin/env ruby
# Example demonstrating "Design by Contract", Bertrand Meyer's idea for programmatically-
# specifying the contract of use for a class or module and testing it at runtime (usually
# during the testing process)
# This example is adapted from spec/extras/design_by_contract_spec.rb.
# Note: the DesignByContract module uses the AspectDSL module. The #precondition, #postcondition,
# and #invariant methods shown below delegate to AspectDSL methods. Those methods implicitly use
# "self" as the :object to advise. 
 
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'
require 'aquarium/extras/design_by_contract'

module Aquarium
  class PreCond
    def action *args
      p "inside :action"
    end
  
    precondition :method => :action, :message => "Must pass more than one argument." do |jp, *args|
      args.size > 0
    end
  end
end
  
p "This call will fail because the precondition is not satisfied:"
begin
  Aquarium::PreCond.new.action
rescue Aquarium::Extras::DesignByContract::ContractError => e
  p e.inspect
end
p "This call will pass because the precondition is satisfied:"
Aquarium::PreCond.new.action :a1

module Aquarium
  class PostCond
    def action *args
      p "inside :action"
    end
  
    postcondition :method => :action, 
      :message => "Must pass more than one argument and first argument must be non-empty." do |jp, *args|
      args.size > 0 && ! args[0].empty?
    end
  end
end

p "These two calls will fail because the postcondition is not satisfied:"
begin
  Aquarium::PostCond.new.action
rescue Aquarium::Extras::DesignByContract::ContractError => e
  p e.inspect
end
begin
  Aquarium::PostCond.new.action ""
rescue Aquarium::Extras::DesignByContract::ContractError => e
  p e.inspect
end
p "This call will pass because the postcondition is satisfied:"
Aquarium::PostCond.new.action :a1

module Aquarium
  class InvarCond
    def initialize 
      @invar = 0
    end
    attr_reader :invar
    def good_action
      p "inside :good_action"
    end
    def bad_action
      p "inside :bad_action"
      @invar = 1
    end
  
    invariant :methods => /action$/, :message => "Must not change the @invar value." do |jp, *args|
      jp.context.advised_object.invar == 0
    end
  end
end

p "This call will fail because the invariant is not satisfied:"
begin
  Aquarium::InvarCond.new.bad_action
rescue Aquarium::Extras::DesignByContract::ContractError => e
  p e.inspect
end
p "This call will pass because the invariant is satisfied:"
Aquarium::InvarCond.new.good_action
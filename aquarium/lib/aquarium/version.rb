module Aquarium
  module VERSION
    def self.build_tag
      tag = "REL_" + [MAJOR, MINOR, TINY].join('_')
      if defined?(RELEASE_CANDIDATE)
        tag << "_" << RELEASE_CANDIDATE
      end
      tag
    end

    unless defined? MAJOR
      MAJOR  = 0
      MINOR  = 1
      TINY   = 0
      RELEASE_CANDIDATE = ""
      
      # RANDOM_TOKEN: 0.598704893979657
      REV = "$LastChangedRevision: 7 $".match(/LastChangedRevision: (\d+)/)[1]

      STRING = [MAJOR, MINOR, TINY].join('.')
      FULL_VERSION = "#{STRING} (r#{REV})"
      TAG = build_tag

      NAME   = "Aquarium"
      URL    = "http://aquarium.rubyforge.org"  
    
      DESCRIPTION = "#{NAME}-#{FULL_VERSION} - Aspect-Oriented Programming toolkit for Ruby\n#{URL}"
    end
  end
end
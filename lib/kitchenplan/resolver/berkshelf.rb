# Copyright 2014 Disney Enterprises, Inc. All rights reserved
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions are
#  met:
#
#   * Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
#
#   * Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in
#   the documentation and/or other materials provided with the
#   distribution.

class Kitchenplan
  class Resolver
    # This class contains support for the Berkshelf resolver (berkshelf.com).
    # Kitchenplan has historically used librarian-chef, but Berkshelf is gaining
    # popularity in the Chef community so here it is.
    # This resolver will fail if there is no Berksfile in the repository root or
    # if the `berks` command is not in the path.
    class Berkshelf < Kitchenplan::Resolver
      # should commands be run with debug output?
      attr_accessor :debug
      # load up whatever information is necessary to use this dependency resolver.
      def initialize(debug=false)
	@debug = debug
      end
      # return the name of this resolver.
      def name
	"Berkshelf"
      end
      # is this dependency resolver present?  should we use it?
      def present?
	File.exist?("Berksfile") and system("berks > /dev/null 2>&1")
      end
      # actually run the resolver and download the cookbooks we need.
      def fetch_dependencies()
	"berks vendor cookbooks #{(@debug ? '-d' : '-q')}"
      end
      # update dependencies after the initial install
      def update_dependencies()
	"berks vendor cookbooks #{(@debug ? '-d' : '-q')}"
      end
    end
  end
end
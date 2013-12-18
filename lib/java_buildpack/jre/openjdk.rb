# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'fileutils'
require 'java_buildpack/diagnostics/common'
require 'java_buildpack/jre'
require 'java_buildpack/jre/memory/openjdk_memory_heuristic_factory'
require 'java_buildpack/util/format_duration'
require 'java_buildpack/versioned_dependency_component'

module JavaBuildpack::Jre

  # Encapsulates the detect, compile, and release functionality for selecting an OpenJDK JRE.
  class OpenJdk < JavaBuildpack::VersionedDependencyComponent

    def initialize(context)
      super('OpenJDK', context)
      @application.java_home.set home
    end

    def compile
      check_memory
      download_tar
      copy_resources
      mutate_killjava
      mutate_memcalc
      copy_buildpack
    end

    def release
      @application.java_opts
      .add_system_property('java.io.tmpdir', '$TMPDIR')
      .add_option('-XX:OnOutOfMemoryError', killjava)
      .add_option_string("`$PWD/#{@application.relative_path_to(memcalc)} $PWD`")
    end

    protected

    def supports?
      true
    end

    private

    KEY_MEMORY_HEURISTICS = 'memory_heuristics'.freeze

    KEY_MEMORY_SIZES = 'memory_sizes'.freeze

    def copy_buildpack
      dir = File.expand_path(File.dirname(__FILE__))
      puts `echo #{dir}`
      FileUtils.cp_r(File.join(dir, '../../../lib'), home + 'bin')
      FileUtils.cp_r(File.join(dir, '../../../config'), home + 'bin')
    end

    def killjava
      home + 'bin/killjava'
    end

    def memcalc
      home + 'bin/memcalc'
    end

    def check_memory
      sizes      = @configuration[KEY_MEMORY_SIZES] || {}
      heuristics = @configuration[KEY_MEMORY_HEURISTICS] || {}
      OpenJDKMemoryHeuristicFactory.create_memory_heuristic(sizes, heuristics, @version).resolve
    end

    def mutate_killjava
      content = killjava.read
      content.gsub! /@@LOG_FILE_NAME@@/,
                    JavaBuildpack::Diagnostics.get_buildpack_log(@application).relative_path_from(killjava.dirname).to_s

      killjava.open('w') do |f|
        f.write content
        f.fsync
      end
    end

    def mutate_memcalc
      content = memcalc.read
      content.gsub! /@@MEMORY_SIZES@@/, "#{@configuration[KEY_MEMORY_SIZES] || {}}"
      content.gsub! /@@MEMORY_HEURISTICS@@/, "#{@configuration[KEY_MEMORY_HEURISTICS] || {}}"
      content.gsub! /@@JRE_VERSION@@/, "'#{@version}'"

      memcalc.open('w') do |f|
        f.write content
        f.fsync
      end
    end

  end

end

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

require 'component_helper'
require 'diagnostics_helper'
require 'english'
require 'fileutils'
require 'memory_limit_helper'
require 'spec_helper'

describe 'memcalc script' do
  include_context 'component_helper'
  include_context 'diagnostics_helper'
  include_context 'memory_limit_helper'

  let(:memcalc) { app_dir + 'bin' + 'memcalc' }
  let(:target) { `#{memcalc} #{app_dir} 2>/dev/null` }

  before do
    FileUtils.mkdir_p(app_dir + 'bin')
    FileUtils.copy 'resources/openjdk/bin/memcalc', memcalc
    copy_buildpack
    mutate_memcalc
  end

  it 'should calculate memory settings when $MEMORY_LIMIT is set', memory_limit: '1G' do
    expect(target).to match(/-Xmx768M -Xms768M -XX:MaxPermSize=104857K -XX:PermSize=104857K -Xss1M/)
  end

  it 'should return status 0 when $MEMORY_LIMIT is acceptable', memory_limit: '1G' do
    target
    expect($CHILD_STATUS.exitstatus).to eq(0)
  end

  it 'should log the calculated memory settings', memory_limit: '1G' do
    target
    expect(log_contents).to match /calculated JVM memory settings:.*-Xmx768M.*-Xms768M.*-XX:MaxPermSize=104857K.*-XX:PermSize=104857K.*-Xss1M/
  end

  it 'should return status when memory calculation fails because $MEMORY_LIMIT is too small', memory_limit: '1m' do
    target
    expect($CHILD_STATUS.exitstatus).to eq(1)
  end

  it 'should log an appropriate error when memory calculation fails because $MEMORY_LIMIT is too small', memory_limit: '1m' do
    target
    expect(log_contents).to match /Total memory 1M exceeded by configured memory/
  end

  it 'should return invalid memory settings when $MEMORY_LIMIT is too small', memory_limit: '1m' do
    expect(target).to match(/-Xmx0k/)
  end

  def copy_buildpack
    dir = File.expand_path(File.dirname(__FILE__))
    puts `echo #{dir}`
    FileUtils.cp_r(File.join(dir, '../../../lib'), app_dir + 'bin')
    FileUtils.cp_r(File.join(dir, '../../../config'), app_dir + 'bin')
  end

  def mutate_memcalc
    content = memcalc.read
    content.gsub! /@@MEMORY_SIZES@@/, "{'permgen'=>'64m..'}"
    content.gsub! /@@MEMORY_HEURISTICS@@/, "{'heap'=>75, 'permgen'=>10, 'stack'=>5, 'native'=>10}"
    content.gsub! /@@JRE_VERSION@@/, "'1.7.0'"

    memcalc.open('w') do |f|
      f.write content
      f.fsync
    end
  end

end

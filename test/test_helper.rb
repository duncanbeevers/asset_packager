$:.unshift(File.dirname(__FILE__) + '/../lib')

# Setup
require 'test/unit'
require 'rubygems'

require 'ruby-debug'
Debugger.settings[:autoeval] = true
Debugger.start

require 'yaml'

require File.join(File.dirname(__FILE__), '../init')

class Test::Unit::TestCase
  def assert_same_elements a, b
    assert_equal a.sort, b.sort, "Expected #{a.inspect} to have the same elements as #{b.inspect}"
  end
  
  def assert_precedes antecedent, consequent, list, message = nil
    a_index = list.index(antecedent)
    c_index = list.index(consequent)
    assert_not_equal -1, a_index,
      "Expected #{antecedent.inspect} to exist in #{list.inspect}"
    assert_not_equal -1, c_index,
      "Expected #{consequent.inspect} to exist in #{list.inspect}"
    assert a_index < c_index,
      message || "Expected #{antecedent.inspect} to precede #{consequent.inspect} in #{list.inspect}"
  end
  
  def assert_package_generates_body(package, expected_body)
    package.package!
    assert_equal expected_body, File.read(package.target)
  end

  def assert_package_generates_resource(package, resource, expected_resource_body)
    package.package!
    assert_equal expected_resource_body, File.read(resource)
  end
end

def sweep_tmp!
  FileUtils.rm_rf('test/tmp')
  FileUtils.mkdir_p('test/tmp/public/stylesheets')
  FileUtils.mkdir_p('test/tmp/public/javascripts')
end

sweep_tmp!

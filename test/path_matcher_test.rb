
require 'test/unit'
require 'dot'

class PathMatcherTest < Test::Unit::TestCase
  
  def new_pm(*args)
    Dot::PathMatcher.new *args
  end
  
  def test_basic_path
    pm = new_pm 'some///path'
    assert_nil pm.resolve('blah!')
    assert Hash==pm.resolve('some//path').class
  end
  
  def test_basic_path_and_defaults
    pm = new_pm('one/two', :defaults=>{:id=>100})
    assert_nil pm.resolve('a')
    assert_equal({:id=>100}, pm.resolve('one/two'))
  end
  
  def test_with_params
    pm = new_pm('one/two/:three', :rules=>{:three=>/^3$/})
    assert_nil pm.resolve('one/two/three')
    assert_equal({:three=>'3'}, pm.resolve('one/two/3'))
  end
  
  def test_with_params_and_defaults
    pm = new_pm('one/two/:three/:mode', :rules=>{:three=>/^3$/, :mode=>/^on$|^off$/}, :defaults=>{:mode=>'on'})
    assert_nil pm.resolve('one/two/three')
    assert_equal({:three=>'3', :mode=>'on'}, pm.resolve('one/two/3'))
    assert_equal({:three=>'3', :mode=>'off'}, pm.resolve('one/two/3/off'))
    assert_nil pm.resolve('one/two/3/blah')
  end
  
end
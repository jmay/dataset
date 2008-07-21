require File.dirname(__FILE__) + '/spec_helper'

describe 'stringifying recipes' do
  it "should stringify correctly" do
    recipe = [ {'command' => 'stage1', 'args' => { 'param' => 1 }}, {'command' => 'stage2', 'args' => { 'param' => 1, 'other' => 'foobar' }} ]
    Dataset.recipe_to_script(recipe).should == "stage1 --param '1'\nstage2 --param '1' --other 'foobar'\n"
  end

  it "should stringify multi-value args" do
    recipe = [ {'command' => 'stage1', 'args' => { 'column' => [1,2,3] }} ]
    Dataset.recipe_to_script(recipe).should == "stage1 --column '1' --column '2' --column '3'\n"
  end

  it "should handle no-args commands" do
    recipe = [ {'command' => 'stage1'}, {'command' => 'stage2'} ]
    Dataset.recipe_to_script(recipe).should == "stage1\nstage2\n"
  end
end

describe "constructing recipes from strings" do
  it "should handle multi-stage recipes" do
    script = "stage1\nstage2\nstage3\n"
    Dataset.script_to_recipe(script).should == [ {'command' => 'stage1'}, {'command' => 'stage2'}, {'command' => 'stage3'}]
  end

  it "should handle stage args" do
    script = "stage1 --param 'foo'"
    Dataset.script_to_recipe(script).should == [ {'command' => 'stage1', 'args' => {'param' => 'foo'}} ]
  end

  it "should handle multi-value args" do
    script = "stage1 --param 'foo' --param 'bar'"
    Dataset.script_to_recipe(script).should == [ {'command' => 'stage1', 'args' => {'param' => ['foo', 'bar']}} ]
  end
end

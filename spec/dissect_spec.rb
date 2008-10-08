require File.dirname(__FILE__) + '/spec_helper'

describe "dissection" do
  it "should identify chron and measure columns" do
    dissection = Dataset::Dissect.new(:input => testdata("simple.tsv"))
    dissection.recipe.should == [
      {'command' => 'chronify.rb', 'args' => {:column => '0:YYYY'}},
      {'command' => 'measures.rb', 'args' => {:column => '1'}}]
  end

  it "should identify dimension columns" do
    dissection = Dataset::Dissect.new(:input => testdata("percentages.tsv"))
    dissection.recipe.should == [
      {'command' => 'chronify.rb', 'args' => {:column => '0:YYYY'}},
      {'command' => 'measures.rb', 'args' => {:column => '2'}},
      {'command' => 'dimension.rb', 'args' => {:columns => '1'}}
      ]
  end

  it "should recognize obvious header rows" do
  end
end

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'thor/actions'

describe Thor::Actions::Template do
  before(:each) do
    ::FileUtils.rm_rf(destination_root)
  end

  def template(source, destination=nil, options={})
    @base = begin
      base = Object.new
      stub(base).source_root{ source_root }
      stub(base).destination_root{ destination_root }
      stub(base).options{ options }
      stub(base).shell{ @shell = Thor::Shell::Basic.new }
      base.instance_variable_set('@klass', 'Config')
      base
    end

    @action = Thor::Actions::Template.new(base, source, destination || source, !@silence)
  end

  def invoke!
    capture(:stdout){ @action.invoke! }
  end

  def revoke!
    capture(:stdout){ @action.revoke! }
  end

  def silence!
    @silence = true
  end

  describe "#invoke!" do
    it "copies the file to the default destination" do
      template("doc/config.rb")
      invoke!
      file = File.join(destination_root, "doc/config.rb")
      File.exists?(file).must be_true
      File.read(file).must == "class Config; end\n"
    end

    it "copies the file to the specified destination" do
      template("doc/config.rb", "doc/configuration.rb")
      invoke!
      file = File.join(destination_root, "doc/configuration.rb")
      File.exists?(file).must be_true
    end

    it "shows created status to the user" do
      template("doc/config.rb")
      invoke!.must == "   [CREATED] doc/config.rb\n"
    end

    it "does not show any information if log status is false" do
      silence!
      template("doc/config.rb")
      invoke!.must be_empty
    end

    describe "when file exists" do
      before(:each) do
        template("doc/config.rb")
        invoke!
      end

      describe "and is identical" do
        it "shows identical status" do
          template("doc/config.rb")
          invoke!
          invoke!.must == " [IDENTICAL] doc/config.rb\n"
        end
      end

      describe "and is not identical" do
        before(:each) do
          File.open(File.join(destination_root, 'doc/config.rb'), 'w'){ |f| f.write("FOO = 3") }
        end

        it "shows forced status to the user if force is given" do
          template("doc/config.rb", "doc/config.rb", :force => true).must_not be_identical
          invoke!.must == "    [FORCED] doc/config.rb\n"
        end

        it "shows skipped status to the user if skip is given" do
          template("doc/config.rb", "doc/config.rb", :skip => true).must_not be_identical
          invoke!.must == "   [SKIPPED] doc/config.rb\n"
        end

        it "shows conflict status to ther user" do
          template("doc/config.rb").must_not be_identical
          mock($stdin).gets{ 's' }
          file = File.join(destination_root, 'doc/config.rb')

          content = invoke!
          content.must =~ /  \[CONFLICT\] doc\/config\.rb/
          content.must =~ /Overwrite #{file}\? \(enter "h" for help\) \[Ynaqdh\]/
          content.must =~ /   \[SKIPPED\] doc\/config\.rb/
        end

        it "creates the file if the file collision menu returns true" do
          template("doc/config.rb")
          mock($stdin).gets{ 'y' }
          invoke!.must =~ /   \[FORCED\] doc\/config\.rb/
        end

        it "skips the file if the file collision menu returns false" do
          template("doc/config.rb")
          mock($stdin).gets{ 'n' }
          invoke!.must =~ /   \[SKIPPED\] doc\/config\.rb/
        end

        it "executes the block given to show file content" do
          template("doc/config.rb")
          mock($stdin).gets{ 'd' }
          mock($stdin).gets{ 'n' }
          invoke!.must =~ /\-FOO = 3/
        end
      end
    end
  end

  describe "#revoke!" do
    it "removes the destination file" do
      template("doc/config.rb")
      invoke!
      revoke!
      File.exists?(@action.destination).must be_false
    end
  end

  describe "#render" do
    it "renders the template" do
      template("doc/config.rb").render.must == "class Config; end\n"
    end
  end

  describe "#exists?" do
    it "returns true if the destination file exists" do
      template("doc/config.rb")
      @action.exists?.must be_false
      invoke!
      @action.exists?.must be_true
    end
  end

  describe "#identical?" do
    it "returns true if the destination file and is identical" do
      template("doc/config.rb")
      @action.identical?.must be_false
      invoke!
      @action.identical?.must be_true
    end
  end
end

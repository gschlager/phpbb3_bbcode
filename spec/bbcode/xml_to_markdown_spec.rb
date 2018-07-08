require 'rspec'
require 'bbcode/xml_to_markdown'

RSpec.describe BBCode::XmlToMarkdown do
  def convert(xml)
    BBCode::XmlToMarkdown.new(xml).convert
  end

  it "converts unformatted text" do
    xml = '<r>unformatted text</r>'
    expect(convert(xml)).to eq('unformatted text')
  end

  it "converts bold text" do
    xml = '<r><B><s>[b]</s>this is bold text<e>[/b]</e></B></r>'
    expect(convert(xml)).to eq('**this is bold text**')
  end

  it "converts italic text" do
    xml = '<r><I><s>[i]</s>this is italic text<e>[/i]</e></I></r>'
    expect(convert(xml)).to eq('_this is italic text_')
  end

  it "converts underlined text" do
    xml = '<r><U><s>[u]</s>this is underlined text<e>[/u]</e></U></r>'
    expect(convert(xml)).to eq('[u]this is underlined text[/u]')
  end

  context "code blocks" do
    it "converts single line code blocks" do
      xml = '<r><CODE><s>[code]</s>one line of code<e>[/code]</e></CODE></r>'
      expect(convert(xml)).to eq('`one line of code`')
    end

    it "converts multi-line code blocks" do
      xml = <<~XML
        <r><CODE><s>[code]</s><i>
        </i> /\_/\
        ( o.o )
         &gt; ^ &lt;
         <e>[/code]</e></CODE></r>
      XML

      expect(convert(xml)).to eq(<<~MD.strip)
        ```text
         /\_/\
        ( o.o )
         > ^ <
        ```
      MD
    end
  end

  context "lists" do
    it "converts unordered lists" do
      xml = <<~XML
        <r><LIST><s>[list]</s>
        <LI><s>[*]</s>Red</LI>
        <LI><s>[*]</s>Blue</LI>
        <LI><s>[*]</s>Yellow</LI>
        <e>[/list]</e></LIST></r>
      XML

      expect(convert(xml)).to eq(<<~MD.strip)
        * Red
        * Blue
        * Yellow
      MD
    end

    it "converts ordered lists" do
      xml = <<~XML
        <r><LIST type="decimal"><s>[list=1]</s>
        <LI><s>[*]</s>Go to the shops</LI>
        <LI><s>[*]</s>Buy a new computer</LI>
        <LI><s>[*]</s>Swear at computer when it crashes</LI>
        <e>[/list]</e></LIST></r>
      XML

      expect(convert(xml)).to eq(<<~MD.strip)
        1. Go to the shops
        2. Buy a new computer
        3. Swear at computer when it crashes
      MD
    end

    it "converts all types of ordered lists into regular ordered lists" do
      xml = <<~XML
        <r><LIST type="upper-alpha"><s>[list=A]</s>
        <LI><s>[*]</s>The first possible answer</LI>
        <LI><s>[*]</s>The second possible answer</LI>
        <LI><s>[*]</s>The third possible answer</LI>
        <e>[/list]</e></LIST></r>
      XML

      expect(convert(xml)).to eq(<<~MD.strip)
        1. The first possible answer
        2. The second possible answer
        3. The third possible answer
      MD
    end

    it "adds leading and trailing newlines to lists if needed" do
      xml = <<~XML
        <r>foo
        <LIST><s>[list]</s>
        <LI><s>[*]</s>Red</LI>
        <LI><s>[*]</s>Blue</LI>
        <LI><s>[*]</s>Yellow</LI>
        <e>[/list]</e></LIST>
        bar</r>
      XML

      expect(convert(xml)).to eq(<<~MD.strip)
        foo

        * Red
        * Blue
        * Yellow

        bar
      MD
    end

    it "converts nested lists" do
      xml = <<~XML
        <r><LIST><s>[list]</s>
        <LI><s>[*]</s>Option 1
           <LIST><s>[list]</s>
              <LI><s>[*]</s>Option 1.1</LI>
              <LI><s>[*]</s>Option 1.2</LI>
           <e>[/list]</e></LIST></LI>
        <LI><s>[*]</s>Option 2
           <LIST><s>[list]</s>
              <LI><s>[*]</s>Option 2.1
                 <LIST type="decimal"><s>[list=1]</s>
                    <LI><s>[*]</s> Red</LI>
                    <LI><s>[*]</s> Blue</LI>
                 <e>[/list]</e></LIST></LI>
              <LI><s>[*]</s>Option 2.2</LI>
           <e>[/list]</e></LIST></LI>
        <e>[/list]</e></LIST></r>
      XML

      expect(convert(xml)).to eq(<<~MD.strip)
        * Option 1
          * Option 1.1
          * Option 1.2
        * Option 2
          * Option 2.1
            1. Red
            2. Blue
          * Option 2.2
      MD
    end
  end

  context "images" do
    it "converts image" do
      xml = <<~XML
        <r><IMG src="https://example.com/foo.png"><s>[img]</s>
        <URL url="https://example.com/foo.png">
        <LINK_TEXT text="https://example.com/foo.png">https://example.com/foo.png</LINK_TEXT>
        </URL><e>[/img]</e></IMG></r>
      XML

      expect(convert(xml)).to eq('![](https://example.com/foo.png)')
    end

    it "converts image with link" do
      xml = <<~XML
        <r><URL url="https://example.com/"><s>[url=https://example.com/]</s>
        <IMG src="https://example.com/foo.png"><s>[img]</s>
        <LINK_TEXT text="https://example.com/foo.png">https://example.com/foo.png</LINK_TEXT>
        <e>[/img]</e></IMG><e>[/url]</e></URL></r>
      XML

      expect(convert(xml)).to eq('[![](https://example.com/foo.png)](https://example.com/)')
    end
  end

  context "links" do
    it "converts links created without BBCode" do
      xml = '<r><URL url="https://en.wikipedia.org/wiki/Capybara">https://en.wikipedia.org/wiki/Capybara</URL></r>'
      expect(convert(xml)).to eq('https://en.wikipedia.org/wiki/Capybara')
    end

    it "converts links created with BBCode" do
      xml = '<r><URL url="https://en.wikipedia.org/wiki/Capybara"><s>[url]</s>https://en.wikipedia.org/wiki/Capybara<e>[/url]</e></URL></r>'
      expect(convert(xml)).to eq('https://en.wikipedia.org/wiki/Capybara')
    end

    it "converts links with link text" do
      xml = '<r><URL url="https://en.wikipedia.org/wiki/Capybara"><s>[url=https://en.wikipedia.org/wiki/Capybara]</s>Capybara<e>[/url]</e></URL></r>'
      expect(convert(xml)).to eq('[Capybara](https://en.wikipedia.org/wiki/Capybara)')
    end

    it "converts email links created without BBCode" do
      xml = '<r><EMAIL email="foo.bar@example.com">foo.bar@example.com</EMAIL></r>'
      expect(convert(xml)).to eq('<foo.bar@example.com>')
    end

    it "converts email links created with BBCode" do
      xml = '<r><EMAIL email="foo.bar@example.com"><s>[email]</s>foo.bar@example.com<e>[/email]</e></EMAIL></r>'
      expect(convert(xml)).to eq('<foo.bar@example.com>')
    end

    it "converts truncated, long links" do
      xml = <<~XML
        <r><URL url="http://answers.yahoo.com/question/index?qid=20070920134223AAkkPli">
        <s>[url]</s><LINK_TEXT text="http://answers.yahoo.com/question/index ... 223AAkkPli">
        http://answers.yahoo.com/question/index?qid=20070920134223AAkkPli</LINK_TEXT>
        <e>[/url]</e></URL></r>
      XML

      expect(convert(xml)).to eq('http://answers.yahoo.com/question/index?qid=20070920134223AAkkPli')
    end

    it "converts BBCodes inside link text" do
      xml = <<~XML
        <r><URL url="http://example.com"><s>[url=http://example.com]</s>
        <B><s>[b]</s>Hello <I><s>[i]</s>world<e>[/i]</e></I>!<e>[/b]</e></B>
        <e>[/url]</e></URL></r>
      XML

      expect(convert(xml)).to eq('[**Hello _world_!**](http://example.com)')
    end
  end

  it "converts line breaks" do
    xml = <<~XML
      <t>Lorem ipsum dolor sit amet.<br/>
      <br/>
      Consetetur sadipscing elitr.<br/>
      <br/>
      <br/>
      Sed diam nonumy eirmod tempor.</t>
    XML

    expect(convert(xml)).to eq(<<~MD.strip)
      Lorem ipsum dolor sit amet.

      Consetetur sadipscing elitr.

      <br>
      Sed diam nonumy eirmod tempor.
    MD
  end
end
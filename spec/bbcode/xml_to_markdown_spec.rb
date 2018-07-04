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
end
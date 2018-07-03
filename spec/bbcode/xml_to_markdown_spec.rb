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

    it "converts multi line code blocks" do
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
end
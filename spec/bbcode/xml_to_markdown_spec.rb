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
end
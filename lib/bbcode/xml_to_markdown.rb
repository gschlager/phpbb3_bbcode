require 'nokogiri'

module BBCode
  class XmlToMarkdown
    def initialize(xml)
      @doc = Nokogiri::XML(xml)
    end

    def convert
      @markdown = ""
      traverse(@doc)
      @markdown
    end

    protected

    def traverse(node)
      node.children.each { |child| visit(child) }
    end

    def visit(node)
      visitor = "visit_#{node.name}"

      if respond_to?(visitor, include_all: true)
        send(visitor, node)
      else
        puts visitor
        traverse(node)
      end
    end

    def visit_text(node)
      @markdown << node.text
    end

    def visit_B(node)
      @markdown << '**'
    end
  end
end

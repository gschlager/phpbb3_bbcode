require 'nokogiri'

module BBCode
  class XmlToMarkdown
    def initialize(xml)
      @reader = Nokogiri::XML::Reader(xml)
    end

    def convert
      @list_stack = []
      @markdown = ""

      @reader.each { |node| visit(node) }
      @markdown
    end

    protected

    def visit(node)
      visitor = "visit_#{node.name.gsub(/\W/, '_')}"

      if respond_to?(visitor, include_all: true)
        send(visitor, node)
      else
        puts visitor unless visitor == 'visit_r'
      end
    end

    def visit__text(node)
      return if @ignore_node

      if @within_code_block
        @code << text(node)
      else
        text = text(node)
        @markdown << text unless @markdown.empty? && text.strip.empty?
      end
    end

    def visit_B(node)
      @markdown << '**'
    end

    def visit_I(node)
      @markdown << '_'
    end

    def visit_U(node)
      @markdown << (start?(node) ? '[u]' : '[/u]')
    end

    def visit_CODE(node)
      if start?(node)
        @within_code_block = true
        @code = ''
      else
        if @code.include?("\n")
          @code.sub!(/\A[\n\r]*/, '')
          @code.rstrip!
          @markdown = "```text\n#{@code}\n```"
        else
          @markdown = "`#{@code}`"
        end

        @within_code_block = false
        @code = nil
      end
    end

    def visit_LIST(node)
      if start?(node)
        @list_stack << {
            unordered: node.attribute('type').nil?,
            item_count: 0
        }
      else
        @list_stack.pop
      end
    end

    def visit_LI(node)
      return unless start?(node)

      list = @list_stack.last
      depth = @list_stack.size - 1

      list[:item_count] += 1

      indentation = ' ' * 2 * depth
      symbol = list[:unordered] ? '*' : "#{list[:item_count]}."

      @markdown << "#{indentation}#{symbol} "
    end

    # node for "BBCode start tag"
    def visit_s(node)
      @ignore_node = start?(node)
    end

    # node for "BBCode end tag"
    def visit_e(node)
      @ignore_node = start?(node)
    end

    # node for "ignored text"
    def visit_i(node)
      @ignore_node = start?(node)
    end

    def start?(node)
      node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
    end

    def text(node)
      CGI.unescapeHTML(node.outer_xml)
    end
  end
end

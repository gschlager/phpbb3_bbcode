require 'nokogiri'

module BBCode
  class XmlToMarkdown
    def initialize(xml)
      @reader = Nokogiri::XML::Reader(xml) do |config|
        config.noblanks
      end
    end

    def convert
      @list_stack = []
      @ignore_node_count = 0
      @markdown = ""

      @reader.each { |node| visit(node) }
      @markdown.rstrip
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
      return if @ignore_node_count > 0

      if @within_code_block
        @code << text(node)
      else
        text = text(node)

        if @markdown.empty?
          @markdown << text unless text.strip.empty?
        else
          @markdown << text.strip
          @markdown << "\n" if text.match?(/\n\s*\z/)
        end
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
        add_new_line_around_list

        @list_stack << {
            unordered: node.attribute('type').nil?,
            item_count: 0
        }
      else
        @list_stack.pop
        add_new_line_around_list
      end
    end

    def add_new_line_around_list
      return if @markdown.empty?
      @markdown << "\n" unless @markdown.end_with?("\n") && @list_stack.size > 0
    end

    def visit_LI(node)
      if start?(node)
        list = @list_stack.last
        depth = @list_stack.size - 1

        list[:item_count] += 1

        indentation = ' ' * 2 * depth
        symbol = list[:unordered] ? '*' : "#{list[:item_count]}."

        @markdown << "#{indentation}#{symbol} "
      else
        @markdown << "\n" unless @markdown.end_with?("\n")
      end
    end

    def visit_IMG(node)
      ignore_node(node)
      @markdown << "![](#{node.attribute('src')})" if start?(node)
    end

    # node for "BBCode start tag"
    def visit_s(node)
      ignore_node(node)
    end

    # node for "BBCode end tag"
    def visit_e(node)
      ignore_node(node)
    end

    # node for "ignored text"
    def visit_i(node)
      ignore_node(node)
    end

    def start?(node)
      node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
    end

    def ignore_node(node)
      @ignore_node_count += start?(node) ? 1 : -1
    end

    def text(node)
      CGI.unescapeHTML(node.outer_xml)
    end
  end
end

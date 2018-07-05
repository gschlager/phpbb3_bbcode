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
      @element_stack = []
      @ignore_node_count = 0
      @markdown = ""

      @reader.each { |node| visit(node) }
      @markdown.rstrip
    end

    protected

    def visit(node)
      visitor = "visit_#{node.name.gsub(/\W/, '_')}"
      is_start_element = start?(node)

      @element_stack.pop if !is_start_element && @element_stack.last == node.name
      send(visitor, node) if respond_to?(visitor, include_all: true)
      @element_stack << node.name if is_start_element
    end

    def visit__text(node)
      return if @ignore_node_count > 0

      if @within_code_block
        @code << text(node)
      else
        text = text(node)
        trimmed_text = text.strip

        return if @url && @url == trimmed_text

        add_link do
          if @markdown.empty?
            @markdown << text unless trimmed_text.empty?
          else
            @markdown << trimmed_text
            @markdown << "\n" if text.match?(/\n\s*\z/)
          end
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

      add_link do
        @markdown << "![](#{node.attribute('src')})" if start?(node)
      end
    end

    def visit_URL(node)
      return if @element_stack.last == 'IMG'

      if start?(node)
        @url = node.attribute('url')
      else
        @markdown << @url if @url
        @url = nil
      end
    end

    def visit_EMAIL(node)
      @markdown << (start?(node) ? '<' : '>')
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

    def add_link
      @markdown << '[' if @url

      yield

      @markdown << "](#{@url})" if @url
      @url = nil
    end
  end
end

require 'nokogiri'
require_relative 'markdown_node'

module BBCode
  class XmlToMarkdown
    def initialize(xml, opts = {})
      @username_from_user_id = opts[:username_from_user_id]
      @smilie_to_emoji = opts[:smilie_to_emoji]
      @quoted_post_from_post_id = opts[:quoted_post_from_post_id]
      @upload_md_from_file = opts[:upload_md_from_file]
      @url_replacement = opts[:url_replacement]
      @allow_inline_code = opts.fetch(:allow_inline_code, false)
      @traditional_linebreaks = opts.fetch(:traditional_linebreaks, false)

      @doc = Nokogiri::XML(xml)
      @list_stack = []
    end

    def convert
      preprocess_xml

      md_root = MarkdownNode.new(xml_node_name: "ROOT", parent: nil)
      visit(@doc.root, md_root)
      to_markdown(md_root).rstrip
    end

    private

    IGNORED_ELEMENTS = ["s", "e", "i"]
    ELEMENTS_WITHOUT_WHITESPACES = ["LIST", "LI"]
    ELEMENTS_WITH_HARD_LINEBREAKS = ["B", "I", "U"]

    def preprocess_xml
      @doc.traverse do |node|
        if node.is_a? Nokogiri::XML::Text
          node.content = node.content.gsub(/\A\n+\s*/, "")
          node.content = node.content.strip if ELEMENTS_WITHOUT_WHITESPACES.include?(node.parent&.name)
          node.remove if node.content.empty?
        elsif IGNORED_ELEMENTS.include?(node.name)
          node.remove
        end
      end
    end

    def visit(xml_node, md_parent)
      visitor = "visit_#{xml_node.name}"
      visitor_exists = respond_to?(visitor, include_all: true)

      if visitor_exists && md_parent.children
        md_node = create_node(xml_node, md_parent)
        send(visitor, xml_node, md_node)
      end

      xml_node.children.each { |xml_child| visit(xml_child, md_node || md_parent) }

      after_hook = "after_#{xml_node.name}"
      if respond_to?(after_hook, include_all: true)
        send(after_hook, xml_node, md_node)
      end
    end

    def create_node(xml_node, md_parent)
      if xml_node.name == "br"
        last_child = md_parent.children.last
        return last_child if last_child&.xml_node_name == "br"
      end

      MarkdownNode.new(xml_node_name: xml_node.name, parent: md_parent)
    end

    def visit_text(xml_node, md_node)
      md_node.text << text(xml_node).gsub("\n", "")
    end

    def visit_B(xml_node, md_node)
      if xml_node.parent&.name != 'B'
        md_node.enclosed_with = "**"
      end
    end

    def visit_I(xml_node, md_node)
      if xml_node.parent&.name != 'I'
        md_node.enclosed_with = "_"
      end
    end

    def visit_U(xml_node, md_node)
      if xml_node.parent&.name != 'U'
        md_node.prefix = "[u]"
        md_node.postfix = "[/u]"
      end
    end

    def visit_CODE(xml_node, md_node)
      content = xml_node.content

      if !@allow_inline_code || content.include?("\n")
        md_node.prefix = "```text\n"
        md_node.postfix = "\n```"
      else
        md_node.enclosed_with = "`"
      end

      md_node.text = content.rstrip
      md_node.skip_children
      md_node.prefix_linebreaks = md_node.postfix_linebreaks = 2
    end

    def visit_LIST(xml_node, md_node)
      md_node.prefix_linebreaks = md_node.postfix_linebreaks = @list_stack.size == 0 ? 2 : 1
      @list_stack << {
        unordered: xml_node.attribute('type').nil?,
        item_count: 0
      }
    end

    def after_LIST(xml_node, md_node)
      @list_stack.pop
    end

    def visit_LI(xml_node, md_node)
      list = @list_stack.last
      depth = @list_stack.size - 1

      list[:item_count] += 1

      indentation = ' ' * 2 * depth
      symbol = list[:unordered] ? '*' : "#{list[:item_count]}."

      md_node.prefix = "#{indentation}#{symbol} "
      md_node.postfix_linebreaks = 1
    end

    def visit_IMG(xml_node, md_node)
      md_node.text = "![](#{xml_node.attribute('src')})"
      md_node.prefix_linebreaks = md_node.postfix_linebreaks = 2
      md_node.skip_children
    end

    def visit_URL(xml_node, md_node)
      original_url = xml_node.attribute('url').to_s
      url = CGI.unescapeHTML(original_url)
      url = @url_replacement.call(url) if @url_replacement

      if xml_node.content.strip == original_url
        md_node.text = url
        md_node.skip_children
      else
        md_node.prefix = "["
        md_node.postfix = "](#{url})"
      end
    end

    def visit_EMAIL(xml_node, md_node)
      md_node.prefix = "<"
      md_node.postfix = ">"
    end

    def visit_br(xml_node, md_node)
      md_node.postfix_linebreaks += 1

      if md_node.postfix_linebreaks > 1 && ELEMENTS_WITH_HARD_LINEBREAKS.include?(xml_node.parent&.name)
        md_node.force_hard_linebreak = true
      end
    end

    def visit_E(xml_node, md_node)
      if @smilie_to_emoji
        md_node.text = @smilie_to_emoji.call(xml_node.content)
        md_node.skip_children
      end
    end

    def visit_QUOTE(xml_node, md_node)
      if post = quoted_post(xml_node)
        md_node.prefix = %Q{[quote="#{post[:username]}, post:#{post[:post_number]}, topic:#{post[:topic_id]}"]\n}
        md_node.postfix = "\n[/quote]"
      elsif username = quoted_username(xml_node)
        md_node.prefix = %Q{[quote="#{username}"]\n}
        md_node.postfix = "\n[/quote]"
      else
        md_node.prefix_children = "> "
      end

      md_node.prefix_linebreaks = md_node.postfix_linebreaks = 2
    end

    def quoted_post(xml_node)
      if @quoted_post_from_post_id
        post_id = to_i(xml_node.attr("post_id"))
        @quoted_post_from_post_id.call(post_id) if post_id
      end
    end

    def quoted_username(xml_node)
      if @username_from_user_id
        user_id = to_i(xml_node.attr("user_id"))
        username = @username_from_user_id.call(user_id) if user_id
      end

      username = xml_node.attr("author") unless username
      username
    end

    def to_i(string)
      string.to_i if string&.match(/\A\d+\z/)
    end

    def visit_ATTACHMENT(xml_node, md_node)
      filename = xml_node.attr("filename")
      index = to_i(xml_node.attr("index"))

      md_node.text = @upload_md_from_file.call(filename, index)
      md_node.prefix_linebreaks = md_node.postfix_linebreaks = 1
      md_node.skip_children
    end

    def visit_SIZE(xml_node, md_node)
      size = to_i(xml_node.attr("size"))
      return if size.nil?

      if size.between?(1, 99)
        md_node.prefix = '<small>'
        md_node.postfix = '</small>'
      elsif size.between?(101, 200)
        md_node.prefix = '<big>'
        md_node.postfix = '</big>'
      end
    end

    def text(xml_node, escape_markdown: true)
      text = CGI.unescapeHTML(xml_node.text)
      # text.gsub!(/[\\`*_{}\[\]()#+\-.!~]/) { |c| "\\#{c}" } if escape_markdown
      text
    end

    # @param md_parent [MarkdownNode]
    def to_markdown(md_parent)
      markdown = ""

      md_parent.children.each do |md_node|
        prefix = md_node.prefix
        text = md_node.children&.any? ? to_markdown(md_node) : md_node.text
        postfix = md_node.postfix

        parent_prefix = prefix_from_parent(md_parent)
        prefix = parent_prefix if parent_prefix && !md_node.text.empty?

        if md_node.xml_node_name != "CODE"
          text, prefix, postfix = hoist_whitespaces!(markdown, text, prefix, postfix)
        end

        force_hard_linebreak = force_hard_linebreak?(md_node)

        add_linebreaks!(markdown, md_node.prefix_linebreaks, force_hard_linebreak, parent_prefix)
        markdown << prefix
        markdown << text
        markdown << postfix
        add_linebreaks!(markdown, md_node.postfix_linebreaks, force_hard_linebreak, parent_prefix)
      end

      markdown
    end

    def hoist_whitespaces!(markdown, text, prefix, postfix)
      text.lstrip! if markdown.end_with?("\n")

      unless prefix.empty?
        if starts_with_whitespace?(text) && !ends_with_whitespace?(markdown)
          prefix = "#{text[0]}#{prefix}"
        end
        text.lstrip!
      end

      unless postfix.empty?
        if ends_with_whitespace?(text)
          postfix = "#{postfix}#{text[-1]}"
        end
        text.rstrip!
      end

      [text, prefix, postfix]
    end

    def prefix_from_parent(md_parent)
      while md_parent
        return md_parent.prefix_children if md_parent.prefix_children
        md_parent = md_parent.parent
      end
    end

    def prefix_children?(md_parent, md_node)
      md_parent.prefix_children && (!md_node.text.empty? || md_node.previous_sibling&.xml_node_name == 'br')
    end

    def force_hard_linebreak?(md_node)
      @traditional_linebreaks || md_node.force_hard_linebreak
    end

    def add_linebreaks!(markdown, required_linebreak_count, force_hard_linebreak, prefix = nil)
      return if required_linebreak_count == 0 || markdown.empty?

      existing_linebreak_count = markdown[/(?:\\?\n)*\z/].count("\n")
      return if required_linebreak_count - existing_linebreak_count <= 0

      markdown.gsub!(/\s*(?:\\?\n)*\z/, '')
      hard_linebreak_start_index = required_linebreak_count > 2 ? 1 : 2

      required_linebreak_count.times do |index|
        use_hard_linebreak = force_hard_linebreak || index >= hard_linebreak_start_index
        linebreak = use_hard_linebreak ? "\\\n" : "\n"

        markdown << (use_hard_linebreak ? prefix : prefix.rstrip) if index > 0 && prefix
        markdown << linebreak
      end
    end

    def starts_with_whitespace?(text)
      text.match?(/\A\s/)
    end

    def ends_with_whitespace?(text)
      text.match?(/\s\z/)
    end
  end
end

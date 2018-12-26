module BBCode
  class MarkdownNode
    # @return [String]
    attr_reader :xml_node_name

    # @return [MarkdownNode]
    attr_reader :parent

    # @return [Array<MarkdownNode>]
    attr_reader :children

    # @return [Array<MarkdownNode>]
    attr_accessor :previous_sibling

    # @return [Array<MarkdownNode>]
    attr_accessor :next_sibling

    # @return [String]
    attr_accessor :text

    # @return [String]
    attr_accessor :prefix

    # @return [String]
    attr_accessor :postfix

    # @return [Integer]
    attr_accessor :prefix_newlines

    # @return [Integer]
    attr_accessor :postfix_newlines

    # @return [String]
    attr_accessor :prefix_children

    # @param xml_node_name [String]
    # @param parent [MarkdownNode]
    def initialize(xml_node_name:, parent:)
      @xml_node_name = xml_node_name

      @text = ""
      @prefix = ""
      @postfix = ""

      @prefix_newlines = 0
      @postfix_newlines = 0

      @parent = parent
      @children = []

      if @parent
        @previous_sibling = @parent.children.last
        @previous_sibling.next_sibling = self if @previous_sibling
        @parent.children << self
      end
    end

    def enclosed_with=(text)
      @prefix = @postfix = text
    end

    def skip_children
      @children = nil
    end

    def to_s
      "name: #{xml_node_name}, prefix: #{prefix}, text: #{text}, children: #{children.size}, postfix: #{postfix}"
    end
  end
end

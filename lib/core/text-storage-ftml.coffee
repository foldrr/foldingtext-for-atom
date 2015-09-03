TextStorage = require './text-storage'
Constants = require './constants'
_ = require 'underscore-plus'
assert = require 'assert'
dom = require './dom'

TextStorage.prototype.toInlineFTMLString = (ownerDocument=document) ->
  div = document.createElement 'div'
  div.appendChild @toInlineFTMLFragment(ownerDocument)
  div.innerHTML

TextStorage.prototype.toInlineFTMLFragment = (ownerDocument=document) ->
  nodeRanges = TextStorage._calculateInitialNodeRanges @, ownerDocument
  nodeRangeStack = [
    start: 0
    end: @getLength()
    node: ownerDocument.createDocumentFragment()
  ]
  TextStorage._buildFragmentFromNodeRanges nodeRanges, nodeRangeStack

TextStorage._calculateInitialNodeRanges = (textStorage, ownerDocument) ->
  # For each attribute run create element nodes for each attribute and text node
  # for the text content. Store node along with range over which is should be
  # applied. Return sorted node ranages.
  nodeRanges = []

  if textStorage.runIndex
    tagsToRanges = {}
    runLocation = 0
    runIndex = 0

    for run in textStorage.getRuns()
      for tag, tagAttributes of run.attributes
        nodeRange = tagsToRanges[tag]
        if not nodeRange or nodeRange.end <= runLocation
          assert(tag is tag.toUpperCase(), 'Tags Names Must be Uppercase')

          element = ownerDocument.createElement tag
          if tagAttributes
            for attrName, attrValue of tagAttributes
              element.setAttribute attrName, attrValue

          nodeRange =
            node: element
            start: runLocation
            end: @_seekTagRangeEnd tag, tagAttributes, runIndex, runLocation, textStorage

          tagsToRanges[tag] = nodeRange
          nodeRanges.push nodeRange

      text = run.getString()
      if text isnt Constants.ObjectReplacementCharacter and text isnt Constants.LineSeparatorCharacter
        nodeRanges.push
          start: runLocation
          end: runLocation + run.getLength()
          node: ownerDocument.createTextNode(text)

      runLocation += run.getLength()
      runIndex++

    nodeRanges.sort @_compareNodeRanges
  else
    string = textStorage.getString()
    nodeRanges = [{
      start: 0
      end: string.length
      node: ownerDocument.createTextNode(string)
    }]

  nodeRanges

TextStorage._seekTagRangeEnd = (tagName, seekTagAttributes, runIndex, runLocation, textStorage) ->
  attributeRuns = textStorage.getRuns()
  end = attributeRuns.length
  while true
    run = attributeRuns[runIndex++]
    runTagAttributes = run.attributes[tagName]
    equalAttributes = runTagAttributes is seekTagAttributes or _.isEqual(runTagAttributes, seekTagAttributes)
    unless equalAttributes
      return runLocation
    else if runIndex is end
      return runLocation + run.getLength()
    runLocation += run.getLength()

TextStorage._compareNodeRanges = (a, b) ->
  if a.start < b.start
    -1
  else if a.start > b.start
    1
  else if a.end isnt b.end
    b.end - a.end
  else
    aNodeType = a.node.nodeType
    bNodeType = b.node.nodeType
    if aNodeType isnt bNodeType
      if aNodeType is Node.TEXT_NODE
        1
      else if bNodeType is Node.TEXT_NODE
        -1
      else
        aTagName = a.node.tagName
        bTagName = b.node.tagName
        if aTagName < bTagName
          -1
        else if aTagName > bTagName
          1
        else
          0
    else
      0

TextStorage._buildFragmentFromNodeRanges = (nodeRanges, nodeRangeStack) ->
  i = 0
  while i < nodeRanges.length
    range = nodeRanges[i++]
    parentRange = nodeRangeStack.pop()
    while nodeRangeStack.length and parentRange.end <= range.start
      parentRange = nodeRangeStack.pop()

    if range.end > parentRange.end
      # In this case each has started inside current parent tag, but
      # extends past. Must split this node range into two. Process
      # start part of split here, and insert end part in correct
      # postion (after current parent) to be processed later.
      splitStart = range
      splitEnd =
        end: splitStart.end
        start: parentRange.end
        node: splitStart.node.cloneNode(true)
      splitStart.end = parentRange.end
      # Insert splitEnd after current parent in correct location.
      j = nodeRanges.indexOf parentRange
      while @_compareNodeRanges(nodeRanges[j], splitEnd) < 0
        j++
      nodeRanges.splice(j, 0, splitEnd)

    parentRange.node.appendChild range.node
    nodeRangeStack.push parentRange
    nodeRangeStack.push range

  nodeRangeStack[0].node

InlineFTMLTags =
  # Inline text semantics
  'A': true
  'ABBR': true
  'B': true
  'BDI': true
  'BDO': true
  'BR': true
  'CITE': true
  'CODE': true
  'DATA': true
  'DFN': true
  'EM': true
  'I': true
  'KBD': true
  'MARK': true
  'Q': true
  'RP': true
  'RT': true
  'RUBY': true
  'S': true
  'SAMP': true
  'SMALL': true
  'SPAN': true
  'STRONG': true
  'SUB': true
  'SUP': true
  'TIME': true
  'U': true
  'VAR': true
  'WBR': true

  # Image & multimedia
  'AUDIO': true
  'IMG': true
  'VIDEO': true

  # Edits
  'DEL': true
  'INS': true

TextStorage._addDOMNodeToTextStorage = (node, textStorage) ->
  nodeType = node.nodeType

  if nodeType is Node.TEXT_NODE
    textStorage.appendTextStorage(new TextStorage(node.nodeValue.replace(/(\r\n|\n|\r)/gm,'')))
  else if nodeType is Node.ELEMENT_NODE
    tagStart = textStorage.getLength()
    each = node.firstChild

    if each
      while each
        @_addDOMNodeToTextStorage(each, textStorage)
        each = each.nextSibling
      if InlineFTMLTags[node.tagName]
        textStorage.addAttributeInRange(node.tagName, @_getElementAttributes(node), tagStart, textStorage.getLength() - tagStart)
    else if InlineFTMLTags[node.tagName]
      if node.tagName is 'BR'
        lineBreak = new TextStorage(Constants.LineSeparatorCharacter)
        lineBreak.addAttributeInRange('BR', @_getElementAttributes(node), 0, 1)
        textStorage.appendTextStorage(lineBreak)
      else if node.tagName is 'IMG'
        image = new TextStorage(Constants.ObjectReplacementCharacter)
        image.addAttributeInRange('IMG', @_getElementAttributes(node), 0, 1)
        textStorage.appendTextStorage(image)

TextStorage._getElementAttributes = (element) ->
  if element.hasAttributes()
    result = {}
    for each in element.attributes
      result[each.name] = each.value
    result
  else
    null

TextStorage.fromInlineFTMLString = (inlineFTMLString) ->
  div = document.createElement 'div'
  div.innerHTML = inlineFTMLString
  @fromInlineFTML div

TextStorage.fromInlineFTML = (inlineFTMLContainer) ->
  textStorage = new TextStorage()
  each = inlineFTMLContainer.firstChild
  while each
    @_addDOMNodeToTextStorage(each, textStorage)
    each = each.nextSibling
  textStorage

TextStorage.validateInlineFTML = (inlineFTMLContainer) ->
  end = dom.nodeNextBranch inlineFTMLContainer
  each = dom.nextNode inlineFTMLContainer
  while each isnt end
    if tagName = each.tagName
      assert.ok(InlineFTMLTags[tagName], "Unexpected tagName '#{tagName}' in 'P'")
    each = dom.nextNode each

TextStorage.inlineFTMLToText = (inlineFTMLContainer) ->
  if inlineFTMLContainer
    end = dom.nodeNextBranch(inlineFTMLContainer)
    each = dom.nextNode inlineFTMLContainer
    text = []

    while each isnt end
      nodeType = each.nodeType

      if nodeType is Node.TEXT_NODE
        text.push(each.nodeValue)
      else if nodeType is Node.ELEMENT_NODE and not each.firstChild
        tagName = each.tagName

        if tagName is 'BR'
          text.push(Constants.LineSeparatorCharacter)
        else if tagName is 'IMG'
          text.push(Constants.ObjectReplacementCharacter)
      each = dom.nextNode(each)
    text.join('')
  else
    ''

TextStorage.textOffsetToInlineFTMLOffset = (offset, inlineFTMLContainer) ->
  if inlineFTMLContainer
    end = dom.nodeNextBranch(inlineFTMLContainer)
    each = inlineFTMLContainer.firstChild or inlineFTMLContainer
    #each = inlineFTMLContainer

    while each isnt end
      nodeType = each.nodeType
      length = 0

      if nodeType is Node.TEXT_NODE
        length = each.nodeValue.length
      else if nodeType is Node.ELEMENT_NODE and not each.firstChild
        tagName = each.tagName

        if tagName is 'BR' or tagName is 'IMG'
          # Count void tags as 1
          length = 1
          if length is offset
            return {} =
              node: each.parentNode
              offset: dom.childIndexOfNode(each) + 1

      if length < offset
        offset -= length
      else
        #if downstreamAffinity and length is offset
        #  next = dom.nextNode(each)
        #  if next
        #    if next.nodeType is Node.ELEMENT_NODE and not next.firstChild
        #      each = next.parentNode
        #      offset = dom.childIndexOfNode(next)
        #    else
        #      each = next
        #      offset = 0
        return {} =
          node: each
          offset: offset
      each = dom.nextNode(each)
  else
    undefined

TextStorage.inlineFTMLOffsetToTextOffset = (node, offset, inlineFTMLContainer) ->
  unless inlineFTMLContainer
    # If inlineFTMLContainer is not provided then search up from node for
    # it. Search for 'P' tagname for model layer or 'contenteditable'
    # attribute for view layer.
    inlineFTMLContainer = node
    while inlineFTMLContainer and
          (inlineFTMLContainer.nodeType is Node.TEXT_NODE or
          not (inlineFTMLContainer.tagName is 'P' or
               inlineFTMLContainer.hasAttribute?('contenteditable')))
      inlineFTMLContainer = inlineFTMLContainer.parentNode

  if node and inlineFTMLContainer and inlineFTMLContainer.contains(node)
    # If offset is > 0 and node is an element then map to child node
    # possition such that a backward walk from that node will cross over
    # all relivant text and void nodes.
    if offset > 0 and node.nodeType is Node.ELEMENT_NODE
      childAtOffset = node.firstChild
      while offset
        childAtOffset = childAtOffset.nextSibling
        offset--

      if childAtOffset
        node = childAtOffset
      else
        node = dom.lastDescendantNodeOrSelf(node.lastChild)

    # Walk backward to inlineFTMLContainer summing text characters and void
    # elements inbetween.
    each = node
    while each isnt inlineFTMLContainer
      nodeType = each.nodeType
      length = 0

      if nodeType is Node.TEXT_NODE
        if each isnt node
          offset += each.nodeValue.length
      else if nodeType is Node.ELEMENT_NODE and each.textContent.length is 0 and not each.firstElementChild
        tagName = each.tagName
        if tagName is 'BR' or tagName is 'IMG'
          # Count void tags as 1
          offset++
      each = dom.previousNode(each)
    offset
  else
    undefined

module.exports = TextStorage
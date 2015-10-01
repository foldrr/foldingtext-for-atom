loadOutlineFixture = require '../load-outline-fixture'
TaskPaper = require '../../lib/taskpaper'
Outline = require '../../lib/core/outline'

describe 'TaskPaper Sync Rules', ->
  [editor, outline, root, one, two, three, four, five, six] = []

  beforeEach ->
    {outline, root, one, two, three, four, five, six} = loadOutlineFixture()
    TaskPaper.initOutline(outline)

  describe 'Body text to attributes', ->

    it 'should sync project sytax to data-type="project"', ->
      one.bodyString = 'my project:'
      one.getAttribute('data-type').should.equal('project')

    it 'should sync task sytax to data-type="task"', ->
      one.bodyString = '- my task:'
      one.getAttribute('data-type').should.equal('task')

    it 'should sync note sytax to data-type="note"', ->
      one.bodyString = 'my note'
      one.getAttribute('data-type').should.equal('note')

    it 'should sync tags to data- attributes', ->
      one.bodyString = '@jesse(washere)'
      one.getAttribute('data-jesse').should.equal('washere')
      one.bodyString = '@jesse(washere) @moose'
      one.getAttribute('data-jesse').should.equal('washere')
      one.getAttribute('data-moose').should.equal('')
      one.bodyString = 'no tags here'
      expect(one.getAttribute('data-jesse')).toBeUndefined()
      expect(one.getAttribute('data-moose')).toBeUndefined()

  describe 'Attributes to body text', ->

    it 'should sync data-type="task" to task syntax', ->
      one.setAttribute('data-type', 'task')
      one.bodyString.should.equal('- one')

    it 'should sync data-type="project" to project syntax', ->
      one.setAttribute('data-type', 'project')
      one.bodyString.should.equal('one:')

    it 'should sync data-type="note" to note syntax', ->
      one.setAttribute('data-type', 'note')
      one.bodyString.should.equal('one')

    it 'should sync between multiple data-types', ->
      one.setAttribute('data-type', 'note')
      one.bodyString.should.equal('one')
      one.setAttribute('data-type', 'project')
      one.bodyString.should.equal('one:')
      one.setAttribute('data-type', 'task')
      one.bodyString.should.equal('- one')
      one.setAttribute('data-type', 'project')
      one.bodyString.should.equal('one:')
      one.setAttribute('data-type', 'note')
      one.bodyString.should.equal('one')

    it 'should sync data- attributes to tags', ->
      one.setAttribute('data-jesse', 'washere')
      one.bodyString.should.equal('one @jesse(washere)')
      one.setAttribute('data-moose', '')
      one.bodyString.should.equal('one @jesse(washere) @moose')
      one.setAttribute('data-jesse', '')
      one.bodyString.should.equal('one @jesse @moose')
      one.removeAttribute('data-jesse', '')
      one.bodyString.should.equal('one @moose')
      one.setAttribute('data-moose', 'mouse')
      one.bodyString.should.equal('one @moose(mouse)')
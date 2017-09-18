_ = window._
moment = window.moment

utils = require('./utils.coffee')

module.exports =
  class BaseModel
    @singular: 'undefinedSingular'
    @plural: 'undefinedPlural'

    # indicate to Loki our 'primary keys' - it promises to make these fast to lookup by.
    @uniqueIndices: ['id']

    # list of other attributes to index
    @indices: []

    @searchableFields: []

    # whitelist of attributes to include when serializing the record.
    # leave null to serialize all attributes
    @serializableAttributes: null

    # what is the key to use when serializing the record?
    @serializationRoot: null

    # override this if your apiEndPoint is not the model.plural
    @apiEndPoint: null
    @memoize: []

    # provides a method which returns a hash with previous and next values.
    # this function takes a hash of options, of which first, last, and pageSize are required.
    # first and last refer to fields on the object, while pageSize is a static value.
    # Example usage:
    # # kennel_model.coffee
    # doggyPagination: @paginate({first: 'firstDogId', last: 'lastDogId', pageSize: 20})
    #
    # # elsewhere
    # kennel.doggyPagination(40)
    # => { prev: 20, next: 60 }
    #
    # first: the name of the field containing the first value of the series.
    # for exmaple, 'firstDogId' would mean that the value of kennel.firstDogId is first index in the series
    # NB: defaults to 0.
    #
    # last: the field containing the last value of the series.
    # for example, 'lastDogId' would mean the value of kennel.lastDogId is the last index in the series.
    # NB: required
    #
    # current: passed into the resulting function,
    #
    # pageSize: the size of a page.
    # for example, with a pageSize of 10, and a current value of 15, calling `paginate(15)`
    # would return {prev: 5, next: 25}
    # TODO: explain this thing better

    @paginate: (opts = {}) ->
      if !(opts.last and opts.pageSize)
        console.log('Pagination missing required options! Please provide last, and pageSize params')
      (current, mapFn = ((v, k) -> [k, v])) ->
        [first, last, pageSize]  = [@[opts.first] or 0, @[opts.last], opts.pageSize]
        current        = current or first
        result         = {}

        result.prev = _.max [current - pageSize, first] if current > first
        result.next = current + pageSize                if current + pageSize <= last

        _.object _.map result, mapFn

    constructor: (recordsInterface, attributes = {}) ->
      @processing = false # not returning/throwing on already processing rn
      @_version = 0
      @attributeNames = []
      @setErrors()
      Object.defineProperty(@, 'recordsInterface', value: recordsInterface, enumerable: false)
      Object.defineProperty(@, 'recordStore', value: recordsInterface.recordStore, enumerable: false)
      Object.defineProperty(@, 'remote', value: recordsInterface.remote, enumerable: false)
      @update(@defaultValues())
      @update(attributes)
      @buildRelationships() if @relationships?
      @applyMemoization()
      @afterConstruction()

    applyMemoization: ->
      _.each @constructor.memoize, (name) =>
        func = @[name]
        @[name] = @recordStore.memoize func, @

    bumpVersion: ->
      # @recordStore.bumpVersion()
      @_version = @_version + 1

    afterConstruction: ->

    defaultValues: ->
      {}

    clone: ->
      cloneAttributes = _.transform @attributeNames, (clone, attr) =>
        if _.isArray(@[attr])
          clone[attr] = @[attr].slice(0)
        else
          clone[attr] = @[attr]
        true
      cloneRecord = new @constructor(@recordsInterface, cloneAttributes)
      cloneRecord.clonedFrom = @
      cloneRecord

    inCollection: =>
      @['$loki']# and @recordsInterface.collection.get(@['$loki'])

    update: (attributes) ->
      @baseUpdate(attributes)

    baseUpdate: (attributes) ->
      @bumpVersion()
      @attributeNames = _.union(@attributeNames, _.keys(attributes))
      _.assign(@, attributes)

      @recordsInterface.collection.update(@) if @inCollection()

    attributeIsModified: (attributeName) ->
      return false unless @clonedFrom?
      original = @clonedFrom[attributeName]
      current = @[attributeName]
      if utils.isTimeAttribute(attributeName)
        !(original == current or current.isSame(original))
      else
        original != current

    modifiedAttributes: ->
      return [] unless @clonedFrom?
      _.filter @attributeNames, (name) =>
        @attributeIsModified(name)

    isModified: ->
      return false unless @clonedFrom?
      @modifiedAttributes().length > 0

    serialize: ->
      @baseSerialize()

    baseSerialize: ->
      wrapper = {}
      data = {}
      paramKey = _.snakeCase(@constructor.serializationRoot or @constructor.singular)

      _.each @constructor.serializableAttributes or @attributeNames, (attributeName) =>
        snakeName = _.snakeCase(attributeName)
        camelName = _.camelCase(attributeName)
        if utils.isTimeAttribute(camelName)
          data[snakeName] = @[camelName].utc().format()
        else
          data[snakeName] = @[camelName]
        true # so if the value is false we don't break the loop

      wrapper[paramKey] = data
      wrapper

    relationships: ->

    buildRelationships: ->
      @views = {}
      @relationships()

    hasMany: (name, userArgs = {}) ->
      args = _.defaults userArgs,
        from: name
        with:  @constructor.singular+'Id'
        of: 'id'
        dynamicView: true

      @[name] = if args.dynamicView
        # sets up a dynamic view which will be kept updated as matching elements are added to the collection
        => @buildView("#{@constructor.singular}_#{@keyOrId()}_#{name}", args).data()
      else
        # adds a simple Records.collection.where with no db overhead
        => @recordStore[args.from].find("#{args.with}": @[args.of])

    buildView: (viewName, args = {}) ->
      # create the view which references the records
      if !@views[viewName]
        @views[viewName] = @recordStore[args.from].collection.addDynamicView(viewName)
        @views[viewName].applyFind("#{args.with}": @[args.of])
        @views[viewName].applySimpleSort(args.sortBy, args.sortDesc) if args.sortBy
      @views[viewName]

    belongsTo: (name, userArgs) ->
      defaults =
        from: name+'s'
        by: name+'Id'

      args = _.assign defaults, userArgs

      @[name] = =>
        @recordStore[args.from].find(@[args.by])

    translationOptions: ->

    isNew: ->
      not @id?

    keyOrId: ->
      if @key?
        @key
      else
        @id

    remove: =>
      @beforeRemove()
      if @inCollection()
        @recordsInterface.collection.remove(@)

    destroy: =>
      @processing = true
      @beforeDestroy()
      @remove()
      @remote.destroy(@keyOrId()).then =>
        @processing = false

    beforeDestroy: =>

    beforeRemove: =>

    save: =>
      @processing = true

      saveSuccess = (records) =>
        @processing = false
        @clonedFrom = undefined
        records

      saveFailure = (errors) =>
        @processing = false
        @setErrors errors
        throw errors

      if @isNew()
        @remote.create(@serialize()).then(saveSuccess, saveFailure)
      else
        @remote.update(@keyOrId(), @serialize()).then(saveSuccess, saveFailure)

    clearErrors: ->
      @errors = {}

    setErrors: (errorList = []) ->
      @errors = {}
      _.each errorList, (errors, key) =>
        @errors[_.camelCase(key)] = errors

    isValid: ->
      @errors.length > 0

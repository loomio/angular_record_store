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

    constructor: (recordsInterface, attributes = {}) ->
      @processing = false # not returning/throwing on already processing rn
      @attributeNames = []
      @setErrors()
      Object.defineProperty(@, 'recordsInterface', value: recordsInterface, enumerable: false)
      Object.defineProperty(@, 'recordStore', value: recordsInterface.recordStore, enumerable: false)
      Object.defineProperty(@, 'remote', value: recordsInterface.remote, enumerable: false)

      @update(@defaultValues())
      @update(attributes)

      @buildRelationships() if @relationships?
      @afterConstruction()

    afterConstruction: ->

    defaultValues: ->
      {}

    clone: ->
      cloneAttributes = _.transform @attributeNames, (clone, attr) =>
        clone[attr] = @[attr]
        true
      cloneRecord = new @constructor(@recordsInterface, cloneAttributes)
      cloneRecord.clonedFrom = @
      cloneRecord

    inCollection: =>
      @['$loki']# and @recordsInterface.collection.get(@['$loki'])

    update: (attributes) ->
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

    hasMany: (name, userArgs) ->
      defaults =
        from: name
        with:  @constructor.singular+'Id'
        of: 'id'
        dynamicView: true

      args = _.assign defaults, userArgs

      # sets up a dynamic view which will be kept updated as matching elements are added to the collection
      addDynamicView = =>
        viewName = "#{@constructor.plural}.#{name}.#{Math.random()}"

        # create the view which references the records
        @views[viewName] = @recordStore[args.from].collection.addDynamicView(name)
        @views[viewName].applyFind("#{args.with}": @[args.of])
        @views[viewName].applySimpleSort(args.sortBy, args.sortDesc) if args.sortBy
        @views[viewName]

        # create fn to retrieve records from the view
        @[name] = =>
          @views[viewName].data()

      # adds a simple Records.collection.where with no db overhead
      addFindMethod = =>
        @[name] = =>
          @recordStore[args.from].find("#{args.with}": @[args.of])

      if args.dynamicView
        addDynamicView()
      else
        addFindMethod()

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
      if @inCollection()
        @recordsInterface.collection.remove(@)

    destroy: =>
      @processing = true
      @remove()
      @remote.destroy(@keyOrId()).then =>
        @processing = false

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

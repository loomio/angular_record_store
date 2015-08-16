_ = window._
moment = window.moment

isTimeAttribute = (attributeName) ->
  /At$/.test(attributeName)

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

    constructor: (recordsInterface, attributes = {}) ->
      @inCollection = false
      @processing = false # not returning/throwing on already processing rn
      @attributeNames = []
      @setErrors()
      Object.defineProperty(@, 'recordsInterface', value: recordsInterface, enumerable: false)
      Object.defineProperty(@, 'recordStore', value: recordsInterface.recordStore, enumerable: false)
      Object.defineProperty(@, 'remote', value: recordsInterface.remote, enumerable: false)

      @update(@defaultValues())
      @update(attributes)

      @buildRelationships() if @relationships?


    defaultValues: ->
      {}

    clone: ->
      cloneAttributes = _.transform @attributeNames, (clone, attr) =>
        clone[attr] = @[attr]
        true
      cloneRecord = new @constructor(@recordsInterface, cloneAttributes)
      cloneRecord.clonedFrom = @
      cloneRecord

    update: (attributes) ->
      @attributeNames = _.union(@attributeNames, _.keys(attributes))
      _.assign(@, attributes)

      # calling update on the collection just updates views/indexes
      @recordsInterface.collection.update(@) if @inCollection

    attributeIsModified: (attributeName) ->
      return false unless @clonedFrom?
      original = @clonedFrom[attributeName]
      current = @[attributeName]
      if isTimeAttribute(attributeName)
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
      paramKey = _.snakeCase(@constructor.singular)
      # lineman/app/components/discussion_form/discussion_form.coffee
      _.each @constructor.serializableAttributes or @attributeNames, (attributeName) =>
        data[_.snakeCase(attributeName)] = @[_.camelCase(attributeName)]
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
        console.log args.from unless @recordStore[args.from]?
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
          console.log args.from unless @recordStore[args.from]?
          @recordStore[args.from].where("#{args.with}": @[args.of])

      if args.dynamicView
        addDynamicView()
      else
        addFindMethod()

    belongsTo: (name, userArgs) =>
      defaults =
        from: name+'s'
        by: name+'Id'

      args = _.assign defaults, userArgs

      @[name] = =>
        console.log args.from unless @recordStore[args.from]?
        @recordStore[args.from].find(@[args.by])

    translationOptions: ->

    isNew: ->
      not @id?

    keyOrId: ->
      if @key?
        @key
      else
        @id

    destroy: =>
      @recordsInterface.collection.remove(@) if @inCollection
      unless @isNew()
        @processing = true
        @remote.destroy(@keyOrId()).then =>
          @processing = false


    save: =>
      saveSuccess = (records) =>
        @processing = false
        @clonedFrom = undefined
        records

      saveFailure = (errors) =>
        @processing = false
        @setErrors errors
        throw errors

      @processing = true
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

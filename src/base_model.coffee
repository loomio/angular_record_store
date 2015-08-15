_ = window._
moment = window.moment

isTimeAttribute = (attributeName) ->
  /At$/.test(attributeName)

module.exports =
  class BaseModel
    @singular: 'undefinedSingular'
    @plural: 'undefinedPlural'
    @indices: []
    @searchableFields: []

    constructor: (recordsInterface, attributes = {}) ->
      @inCollection = false
      @processing = false
      @attributeNames = []
      @setErrors()
      Object.defineProperty(@, 'recordsInterface', value: recordsInterface, enumerable: false)
      Object.defineProperty(@, 'recordStore', value: recordsInterface.recordStore, enumerable: false)
      Object.defineProperty(@, 'restfulClient', value: recordsInterface.restfulClient, enumerable: false)

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
      cloneRecord._clonedFrom = @
      cloneRecord

    update: (attributes) ->
      @attributeNames = _.union(@attributeNames, _.keys(attributes))
      _.assign(@, attributes)
      @recordsInterface.collection.update(@) if @inCollection

    attributeIsModified: (attributeName) ->
      return false unless @_clonedFrom?
      original = @_clonedFrom[attributeName]
      current = @[attributeName]
      if isTimeAttribute(attributeName)
        !(original == current or current.isSame(original))
      else
        original != current

    modifiedAttributes: ->
      return [] unless @_clonedFrom?
      _.filter @attributeNames, (name) =>
        @attributeIsModified(name)

    isModified: ->
      return false unless @_clonedFrom?
      @modifiedAttributes().length > 0

    serialize: ->
      @baseSerialize()

    baseSerialize: ->
      wrapper = {}
      data = {}
      paramKey = _.snakeCase(@constructor.singular)
      _.each window.Loomio.permittedParams[paramKey], (attributeName) =>
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

      args = _.assign defaults, userArgs
      viewName = "#{@constructor.plural}.#{name}.#{Math.random()}"

      # create the view which references the records
      #console.log 'heyyy defaults, userArgs, args, recordStore, collection', defaults, userArgs, args, @recordStore[args.from]
      @views[viewName] = @recordStore[args.from].collection.addDynamicView(name)
      @views[viewName].applyFind("#{args.with}": @[args.of])
      @views[viewName].applySimpleSort(args.sortBy, args.sortDesc) if args.sortBy
      @views[viewName]

      # create fn to retrieve records from the view
      @[name] = =>
        @views[viewName].data()

    belongsTo: (name, args = {from: null, by: null}) =>
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

    save: =>
      @setErrors()
      if @processing
        console.log "save returned, already processing:", @
        return

      @processing = true
      if @isNew()
        @restfulClient.create(@serialize()).then(@saveSuccess, @saveFailure)
      else
        @restfulClient.update(@keyOrId(), @serialize()).then(@saveSuccess, @saveFailure)

    destroy: =>
      @processing = true
      @restfulClient.destroy(@keyOrId()).then =>
        @processing = false
        @recordsInterface.remove(@)
      , ->

    saveSuccess: (records) =>
      # TODO!!!!!! collection update(@)
      @_clonedFrom = undefined
      @processing = false
      records

    saveFailure: (errors) =>
      @processing = false
      @setErrors errors
      throw errors

    setErrors: (errorList = []) ->
      @errors = {}
      _.each errorList, (errors, key) =>
        @errors[_.camelCase(key)] = errors

    isValid: ->
      @errors.length > 0

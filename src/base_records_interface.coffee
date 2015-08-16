_ = window._

transformKeys = (attributes, transformFn) ->
  _.transform _.keys(attributes), (result, key) ->
    result[transformFn(key)] = attributes[key]
    true

parseJSON = (json) ->
  attributes = transformKeys(json, _.camelCase)
  _.each _.keys(attributes), (name) ->
    if attributes[name]?
      if isTimeAttribute(name) and moment(attributes[name]).isValid()
        attributes[name] = moment(attributes[name])
      else
        attributes[name] = attributes[name]
    true
  attributes

isTimeAttribute = (attributeName) ->
  /At$/.test(attributeName)

module.exports = (RestfulClient, $q) ->
  class BaseRecordsInterface
    model: 'undefinedModel'

    constructor: (recordStore) ->
      @baseConstructor recordStore

    baseConstructor: (recordStore) ->
      @recordStore = recordStore
      @collection = @recordStore.db.addCollection(@model.plural, {indices: @model.indices})
      _.each @model.uniqueIndices, (name) =>
        @collection.ensureUniqueIndex(name)

      @remote = new RestfulClient(@model.apiEndPoint or @model.plural)

      @remote.onSuccess = (response) =>
        @recordStore.import(response.data)

      @remote.onFailure = (response) ->
        console.log('request failure!', response)
        throw response

    build: (attributes = {}) ->
      record = new @model @, attributes

    create: (attributes = {}) ->
      record = @build(attributes)
      @collection.insert(record)
      record.inCollection = true
      record

    fetch: (args) ->
      @remote.fetch(args)

    importJSON: (json) ->
      @import(parseJSON(json))

    import: (attributes) ->
      record = @find(attributes.key or attributes.id)
      if record
        record.update(attributes)
      else
        record = @create(attributes)
      record

    findOrFetchById: (id) ->
      deferred = $q.defer()
      promise = @remote.fetchById(id).then => @find(id)

      if record = @find(id)
        deferred.resolve(record)
      else
        deferred.resolve(promise)

      deferred.promise

    find: (q) ->
      if q == null or q == undefined
        undefined
      else if _.isNumber(q)
        @findById(q)
      else if _.isString(q)
        @findByKey(q)
      else if _.isArray(q)
        if q.length == 0
          []
        else if _.isString(q[0])
          @findByKeys(q)
        else if _.isNumber(q[0])
          @findByIds(q)
      else
        @collection.find(q)

    findById: (id) ->
      @collection.by('id', id)

    findByKey: (key) ->
      @collection.by('key', key)

    findByIds: (ids) ->
      @collection.find(id: {'$in': ids})

    findByKeys: (keys) ->
      @collection.find(key: {'$in': keys})

    where: (params) ->
      @collection.chain().find(params).data()

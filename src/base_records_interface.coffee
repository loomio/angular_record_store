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
      @restfulClient = new RestfulClient(@model.plural)

      @restfulClient.onSuccess = (response) =>
        @recordStore.import(response.data)

      @restfulClient.onFailure = (response) ->
        console.log('request failure!', response)
        throw response

    build: (attributes = {}) ->
      record = new @model @, attributes

    create: (attributes = {}) ->
      record = @build(attributes)
      @collection.insert(record)
      record.inCollection = true
      record

    importJSON: (json) ->
      @import(parseJSON(json))

    import: (attributes) ->
      record = @find(attributes.key or attributes.id)
      if record
        record.update(attributes)
      else
        record = @create(attributes)
      record

    remove: (record) ->
      record.inCollection = false
      @collection.remove(record)

    destroy: (id) ->
      @restfulClient.destroy(id)

    findOrFetchById: (id) ->
      deferred = $q.defer()
      promise = @fetchById(id).then => @find(id)

      if record = @find(id)
        deferred.resolve(record)
      else
        deferred.resolve(promise)

      deferred.promise

    fetchById: (id) ->
      @restfulClient.getMember(id)

    fetch: ({params, path}) ->
      if path?
        @restfulClient.get(path, params)
      else
        @restfulClient.getCollection(params)

    find: (q) ->
      if q == null or q == undefined
        null
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
      @collection.findOne(id: id)

    findByKey: (key) ->
      @collection.findOne(key: key)

    findByIds: (ids) ->
      @collection.find(id: {'$in': ids})

    findByKeys: (keys) ->
      @collection.find(key: {'$in': keys})

    where: (params) ->
      @collection.chain().find(params).data()

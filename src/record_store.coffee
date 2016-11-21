_ = window._

module.exports =
  class RecordStore
    constructor: (db) ->
      @db = db
      @collectionNames = []
      @cache = {}

    addRecordsInterface: (recordsInterfaceClass) ->
      recordsInterface = new recordsInterfaceClass(@)
      name = recordsInterface.model.plural
      @[_.camelCase(name)] = recordsInterface
      @collectionNames.push name

    import: (data) ->
      _.each @collectionNames, (name) =>
        snakeName = _.snakeCase(name)
        camelName = _.camelCase(name)
        if data[snakeName]?
          _.each data[snakeName], (recordData) =>
            @[camelName].importJSON(recordData)
      @cache = {}
      data

    memoize: (func) ->
      key = func.toString()
      unless @cache[key]
        @cache[key] = _.memoize(func)
      @cache[key]()

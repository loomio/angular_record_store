_ = window._

module.exports = ($http, Upload) ->
  class RestfulClient
    apiPrefix: "api/v1"

    # override these to set default actions
    onSuccess: (response) -> response
    onFailure: (response) -> throw response

    constructor: (resourcePlural) ->
      @processing = []
      @resourcePlural = _.snakeCase(resourcePlural)

    buildUrl: (url, params) ->
      return url unless params?

      # note to self, untested function.. you'll probably hate yourself for rewriting this rn
      encodeParams = (params) ->
        _.map(_.keys(params), (key) ->
          encodeURIComponent(key) + "=" + encodeURIComponent(params[key])
        ).join('&')

      url + "?" + encodeParams(params)

    defaultParams: {}

    collectionPath: ->
      "#{@apiPrefix}/#{@resourcePlural}"

    memberPath: (id, action) ->
      if action?
        "#{@apiPrefix}/#{@resourcePlural}/#{id}/#{action}"
      else
        "#{@apiPrefix}/#{@resourcePlural}/#{id}"

    customPath: (path) ->
      "#{@apiPrefix}/#{@resourcePlural}/#{path}"

    fetchById: (id) ->
      @getMember(id)

    fetch: ({params, path}) ->
      if path?
        @get(path, params)
      else
        @getCollection(params)

    get: (path, params) ->
      url = @buildUrl(@customPath(path), _.merge(@defaultParams, params))
      $http.get(url).then @onSuccess, @onFailure

    post: (path, params) ->
      $http.post(@customPath(path), _.merge(@defaultParams, params)).then @onSuccess, @onFailure

    upload: (path, file, params = {}, onProgress) ->
      upload = Upload.upload(_.merge(params,
        url: @customPath(path)
        headers: { 'Content-Type': false }
        file: file)
      ).progress(onProgress)
      upload.then(@onSuccess, @onFailure)
      upload

    postMember: (keyOrId, action, params) ->
      $http.post(@memberPath(keyOrId, action), _.merge(@defaultParams, params)).then @onSuccess, @onFailure

    patchMember: (keyOrId, action, params) ->
      $http.patch(@memberPath(keyOrId, action), _.merge(@defaultParams, params)).then @onSuccess, @onFailure

    getMember: (keyOrId, action, params) ->
      $http.get(@memberPath(keyOrId, action), _.merge(@defaultParams, params)).then @onSuccess, @onFailure

    getCollection: (params) ->
      url = @buildUrl(@collectionPath(), _.merge(@defaultParams, params))
      $http.get(url).then @onSuccess, @onFailure

    create: (params) ->
      $http.post(@collectionPath(), _.merge(@defaultParams, params)).then @onSuccess, @onFailure

    update: (id, params) ->
      $http.patch(@memberPath(id), _.merge(@defaultParams, params)).then @onSuccess, @onFailure

    destroy: (id, params) ->
      $http.delete(@memberPath(id), _.merge(@defaultParams, params)).then @onSuccess, @onFailure

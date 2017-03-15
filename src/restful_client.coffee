_ = window._

console.log 'wassip'

module.exports = ($http, Upload) ->
  class RestfulClient
    apiPrefix: "api/v1"

    # override these to set default actions
    onSuccess: (response) -> response
    onFailure: (response) -> throw response

    constructor: (resourcePlural) ->
      @processing = []
      @resourcePlural = _.snakeCase(resourcePlural)

    buildUrl: (path, params) ->
      path = "#{@apiPrefix}/#{@resourcePlural}/#{path}"
      return path unless params?

      # note to self, untested function.. you'll probably hate yourself for rewriting this rn
      encodeParams = (params) ->
        _.map(_.keys(params), (key) ->
          encodeURIComponent(key) + "=" + encodeURIComponent(params[key])
        ).join('&')

      path + "?" + encodeParams(params)

    defaultParams: {}

    memberPath: (id, action) ->
      if action?
        "#{id}/#{action}"
      else
        "#{id}"

    fetchById: (id) ->
      @getMember(id)

    fetch: ({params, path}) ->
      @get(path or '', params)

    get: (path, params) ->
      $http.get(@buildUrl(path, _.merge(@defaultParams, params))).then @onSuccess, @onFailure

    post: (path, params) ->
      $http.post(@buildUrl(path), _.merge(@defaultParams, params)).then @onSuccess, @onFailure

    patch: (path, params) ->
      $http.patch(@buildUrl(path), _.merge(@defaultParams, params)).then @onSuccess, @onFailure

    delete: (path, params) ->
      $http.delete(@buildUrl(path), _.merge(@defaultParams, params)).then @onSuccess, @onFailure

    postMember: (keyOrId, action, params) ->
      @post(@memberPath(keyOrId, action), params)

    patchMember: (keyOrId, action, params) ->
      @patch(@memberPath(keyOrId, action), params)

    getMember: (keyOrId, action = '', params) ->
      @get @memberPath(keyOrId, action), params

    create: (params) ->
      @post('', params)

    update: (id, params) ->
      @patch(id, params)

    destroy: (id, params) ->
      @delete(id, params)

    upload: (path, file, params = {}, onProgress) ->
      upload = Upload.upload(_.merge(params,
        url: @customPath(path)
        headers: { 'Content-Type': false }
        file: file)
      ).progress(onProgress)
      upload.then(@onSuccess, @onFailure)
      upload

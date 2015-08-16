module.exports = (BaseModel) ->             # export a fn injecting BaseModel
  alphabet = 'abcdefghijklmnopqrstuzwxyz'
  pos = 0
  nextLetter = ->
    alphabet[pos++]

  class FleaModel extends BaseModel          # and returning your model class
    @singular: 'flea'                        # term for single *required*
    @plural: 'fleas'                         # term for many *required*
    @indices: ['dogId']                   # array - any attributes often used for lookup
    @serializableAttributes: ['letter', 'biting']

    defaultValues: ->                       # fn returning a object with default values for new records
      letter: nextLetter()
      biting: false

    relationships: ->
      @belongsTo 'dog',                    # sets up dog: -> Records.doggies.find(@dogId)
        from: 'doggies'
        by: 'dogId'

    awaken: ->
      @biting = true

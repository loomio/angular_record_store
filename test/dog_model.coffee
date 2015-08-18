module.exports = (BaseModel) ->             # export a fn injecting BaseModel
  class DogModel extends BaseModel          # and returning your model class
    @singular: 'dog'                        # term for single *required*
    @plural: 'doggies'                      # term for many *required*
    @indices: ['ownerId']                   # any attributes often used for lookup
    @uniqueIndices: ['id', 'key']
    @serializableAttributes: ['id', 'name', 'ownerId']

    defaultValues: ->                       # fn returning a object with default values for new records
      name: null                            # i think this is a good way to define both attributeNames and default values
      age: 0
      isFluffy: true

    relationships: ->                          # describe the relationships with other records
      @hasMany 'fleas',                         # creates a fn fleas that returns all flea records where dog.id == flea.dogId
        sortBy: 'letter'
        sortDesc: true

      @belongsTo 'owner',                       # sets up owner: -> Records.users.find(@ownerId)
        from: 'people'                          # all parameters required for now
        by: 'ownerId'

    ownerName: ->
      @owner.name()                            # add any functions you wish

    scratchSelf: ->
      _.each _.sample(@fleas(), 5), (flea) -> # lodash is available for you
        flea.awaken()


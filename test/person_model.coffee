module.exports = (BaseModel) ->
  class PersonModel extends BaseModel
    @singular: 'person'
    @plural: 'people'
    @indices: ['id', 'age']

    defaultValues: ->
      age: 0
      name: null

    relationships: ->
      @hasMany 'dogs',
        from: 'doggies'
        with: 'ownerId'

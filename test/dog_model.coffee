module.exports = (BaseModel) ->
  class DogModel extends BaseModel
    @singluar: 'dog'
    @plural: 'doggies'

    defaultValues: ->
      isFluffy: true

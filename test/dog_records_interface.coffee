module.exports = (BaseRecordsInterface, DogModel) ->
  class DogRecordsInterface extends BaseRecordsInterface
    model: DogModel

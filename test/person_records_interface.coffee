module.exports = (BaseRecordsInterface, PersonModel) ->
  class PersonRecordsInterface extends BaseRecordsInterface
    model: PersonModel

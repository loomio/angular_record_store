module.exports = (BaseRecordsInterface, FleaModel) ->
  class FleaRecordsInterface extends BaseRecordsInterface
    model: FleaModel

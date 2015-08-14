_ = window._ = require('lodash')
moment = window.moment = require('moment')
angular = require('angular')
mocks = require('angular-mocks/angular-mocks')
moment = require('moment')
loki = require('lokijs')

RecordStore = require('../src/record_store.coffee')
recordStore = new RecordStore(new loki('testdatabase'))

BaseModel = require('../src/base_model.coffee')
DogModel = null

BaseRecordsInterface = null
dogRecordsInterface = null

describe 'model behaviour', ->
  beforeEach ->
    inject ($httpBackend, $q) ->

      RestfulClient = require('../src/restful_client.coffee')($httpBackend, 'fakeUploadService')
      BaseRecordsInterface = require('../src/base_records_interface.coffee')(RestfulClient, $q)

      DogModel = require('./dog_model.coffee')(BaseModel)
      DogRecordsInterface = require('../test/dog_records_interface.coffee')(BaseRecordsInterface, DogModel)

      dogRecordsInterface = new DogRecordsInterface(recordStore)
      recordStore.addRecordsInterface(DogRecordsInterface)

  # things yet to test
  # serialize
  # setupViews is called
  # setErrors sets errors
  # check if we need the postInitalize that clone uses

  describe 'new', ->
    it 'creates new record with default values', ->
      record = new DogModel(recordStore, {})
      expect(record.isFluffy).toBe(true)

  describe 'clone', ->
    record = null
    beforeEach ->
      record = new DogModel(dogRecordsInterface)

    it 'creates a clone of the record with the same values', ->
      cloneRecord = record.clone()

      _.each record.constructor.attributeNames, (attributeName) ->
        expect(cloneRecord[attributeName]).toEqual(record[attributeName])

    it 'isModified is false when not modified', ->
      cloneRecord = record.clone()
      expect(cloneRecord.isModified()).toBe(false)

    it 'isModfied is true when attribute is changed', ->
      cloneRecord = record.clone()
      cloneRecord.isFluffy = false
      expect(cloneRecord.isModified()).toBe(true)

  describe 'updateFromJSON', ->
    record = null

    beforeEach ->
      record = new DogModel(dogRecordsInterface, {})

    it 'assigns attributes snake -> camel case', ->
      json = {is_fluffy: false, some_attr_name: 'aValue'}

      record.updateFromJSON(json)

      expect(record.isFluffy).toBe(false)
      expect(record.someAttrName).toBe('aValue')

    it "momentizes attrbutes ending in _at", ->
      json = {created_at: "2015-08-13T00:00:00Z"}
      record.updateFromJSON(json)
      expect(record.createdAt).toEqual(moment("2015-08-13T00:00:00Z"))

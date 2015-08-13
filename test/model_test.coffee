angular = require('angular')
require('angular-mocks/angular-mocks')

loki = require('lokijs')

RecordStore = require('../src/record_store.coffee')
BaseModel = require('../src/base_model.coffee')
BaseRecordsInterface = null
DogModel = null

dogRecordsInterface = null
recordStore = null
lokidb = null

$upload = 'fakeupload'
db = new loki('testdatabase')
recordStore = new RecordStore(db)

describe 'base model behaviuor', ->

  beforeEach ->
    inject ($httpBackend, $q) ->

      RestfulClient = require('../src/restful_client.coffee')($httpBackend, $upload)
      BaseRecordsInterface = require('../src/base_records_interface.coffee')(RestfulClient, $q)

      DogModel = require('./dog_model.coffee')(BaseModel)
      DogRecordsInterface = require('../test/dog_records_interface.coffee')(BaseRecordsInterface, DogModel)

      dogRecordsInterface = new DogRecordsInterface(recordStore)
      recordStore.addRecordsInterface(DogRecordsInterface)

  # things yet to test
  # serialize
  # setupViews is called
  # setErrors sets errors

  describe 'new', ->
    it 'creates new record with default values', ->
      record = new DogModel(recordStore, {})
      console.log 'dogrecord', record
      expect(record.isFluffy).toBe(true)

  #describe 'clone', ->
    #record = null
    #beforeEach ->
      #record = new DogModel(recordsInterface, {barks: true})

    #it 'isModified is false when not modified', ->
      #cloneRecord = record.clone()
      #expect(cloneRecord.isModified()).toBe(false)

    #it 'isModfied is true when attribute is changed', ->
      #cloneRecord = record.clone()
      #cloneRecord.barks = false
      #expect(cloneRecord.isModified()).toBe(true)

  #describe 'updateFromJSON', ->
    #it 'maps attributes from snake to camelcase',  ->
      #record = new DogModel(recordsInterface, {})
      #json = {is_fluffy: false, barks: true, some_attr_name: 'aValue'}
      #record.updateFromJSON(json)
      #expect(record.someAttrName).toBe('aValue')
      #expect(record.isFulffy).toBe(true)
      #expect(record.barks).toBe(true)

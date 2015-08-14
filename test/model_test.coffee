_ = window._ = require('lodash')
moment = window.moment = require('moment')
angular = require('angular')
mocks = require('angular-mocks/angular-mocks')
moment = require('moment')
loki = require('lokijs')

RecordStore = require('../src/record_store.coffee')

BaseModel = require('../src/base_model.coffee')
BaseRecordsInterface = null

DogModel = null

dog = null
recordStore = null


describe 'model behaviour', ->
  beforeEach ->
    inject ($httpBackend, $q) ->
      recordStore = new RecordStore(new loki('testdatabase'))
      RestfulClient = require('../src/restful_client.coffee')($httpBackend, 'fakeUploadService')
      BaseRecordsInterface = require('../src/base_records_interface.coffee')(RestfulClient, $q)

      DogModel = require('./dog_model.coffee')(BaseModel)
      DogRecordsInterface = require('../test/dog_records_interface.coffee')(BaseRecordsInterface, DogModel)
      recordStore.addRecordsInterface(DogRecordsInterface)

      FleaModel = require('./flea_model.coffee')(BaseModel)
      FleaRecordsInterface = require('../test/flea_records_interface.coffee')(BaseRecordsInterface, FleaModel)
      recordStore.addRecordsInterface(FleaRecordsInterface)

      PersonModel = require('./person_model.coffee')(BaseModel)
      PersonRecordsInterface = require('./person_records_interface.coffee')(BaseRecordsInterface, PersonModel)
      recordStore.addRecordsInterface(PersonRecordsInterface)

      #console.log 'doggies: ', recordStore, recordStore.doggies
      #dog = recordStore.doggies.build(someAttribute: 'hello') # not inserted into collection
      #dog = recordStore.doggies.importJSON(is_fluffy: true, loves_running: true) # insert or update

  describe 'relationships', ->
    cruella = null
    beforeEach ->
      cruella = recordStore.people.create(id: 1, name: 'Curella')
      dog = recordStore.doggies.create(id: 1, ownerId: cruella.id)

      _.times 26, ->
        recordStore.fleas.create(dogId: dog.id)

    describe 'has_many', ->
      it 'creates fn returning collection of related records', ->
        expect(dog.fleas().length).toBe(26)

      it 'can be chained with lokijs calls like applySimpleSort', ->
        expect(dog.fleas()[0].letter).toBe('z')

      it 'scratches an itch', ->
        dog.scratchSelf()
        expect(_.filter(dog.fleas(), 'biting').length).toBe 5

    describe 'belongs_to', ->
      it 'returns corresponding person record', ->
        expect(dog.owner()).toBe(cruella)


  # things yet to test
  # serialize
  # indices
  # attributeNames
  # setErrors sets errors
  # check if we need the postInitalize that clone uses

  #describe 'new', ->
    #it 'creates new record with default values', ->
      #record = new DogModel(recordStore, {})
      #expect(record.isFluffy).toBe(true)

  #describe 'clone', ->
    #record = null
    #beforeEach ->
      #record = new DogModel(dogRecordsInterface)

    #it 'creates a clone of the record with the same values', ->
      #cloneRecord = record.clone()

      #_.each record.constructor.attributeNames, (attributeName) ->
        #expect(cloneRecord[attributeName]).toEqual(record[attributeName])

    #it 'isModified is false when not modified', ->
      #cloneRecord = record.clone()
      #expect(cloneRecord.isModified()).toBe(false)

    #it 'isModfied is true when attribute is changed', ->
      #cloneRecord = record.clone()
      #cloneRecord.isFluffy = false
      #expect(cloneRecord.isModified()).toBe(true)

  #describe 'updateFromJSON', ->
    #record = null

    #beforeEach ->
      #record = new DogModel(dogRecordsInterface, {})

    #it 'assigns attributes snake -> camel case', ->
      #json = {is_fluffy: false, some_attr_name: 'aValue'}

      #record.updateFromJSON(json)

      #expect(record.isFluffy).toBe(false)
      #expect(record.someAttrName).toBe('aValue')

    #it "momentizes attrbutes ending in _at", ->
      #json = {created_at: "2015-08-13T00:00:00Z"}
      #record.updateFromJSON(json)
      #expect(record.createdAt).toEqual(moment("2015-08-13T00:00:00Z"))


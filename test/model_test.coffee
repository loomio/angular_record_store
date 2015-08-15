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

sharedSetup = ->
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

describe 'BaseModel', ->
  beforeEach ->
    sharedSetup()

  describe 'clone', ->
    dog = null
    cloneDog = null

    beforeEach ->
      dog = recordStore.doggies.create(id: 1, name: 'barf')
      cloneDog = dog.clone()

    it 'creates a clone of the record with the same values', ->
      _.each dog.attributeNames, (attributeName) ->
        expect(cloneDog[attributeName]).toEqual(dog[attributeName])

    it 'isModified is false when not modified', ->
      expect(cloneDog.isModified()).toBe(false)

    it 'isModfied is true when attribute is changed', ->
      cloneDog.isFluffy = false
      expect(cloneDog.isModified()).toBe(true)

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

describe 'recordsInterface', ->
  beforeEach ->
    sharedSetup()

  describe 'build', ->
    beforeEach ->
      dog = recordStore.doggies.build(id: 42)

    it 'builds record with default values', ->
      expect(dog.isFluffy).toBe(true)

    it 'does not insert into collection', ->
      expect(dog.inCollection).toBe(false)
      expect(recordStore.doggies.find(42)).toBe(null)

    it 'overrides defaults and allows new properties', ->
      dog = recordStore.doggies.build(isFluffy: false, smellsBad: true)
      expect(dog.isFluffy).toBe(false)
      expect(dog.smellsBad).toBe(true)

  describe 'create', ->
    beforeEach ->
      dog = recordStore.doggies.create(id: 43)

    it 'creates record with default values', ->
      expect(dog.isFluffy).toBe(true)

    it 'inserts it into the record store', ->
      expect(dog.isFluffy).toBe(true)
      expect(recordStore.doggies.find(43)).toBe(dog)

  describe 'importJSON', ->
    dog = null

    beforeEach ->
      json = {is_fluffy: false, some_attr_name: 'aValue', created_at: "2015-08-13T00:00:00Z"}
      dog = recordStore.doggies.importJSON(json)

    it 'assigns attributes snake -> camel case', ->
      expect(dog.isFluffy).toBe(false)
      expect(dog.someAttrName).toBe('aValue')

    it "momentizes attrbutes ending in _at", ->
      expect(dog.createdAt).toEqual(moment("2015-08-13T00:00:00Z"))



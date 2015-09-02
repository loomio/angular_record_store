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
FleaModel = null
PersonModel = null

dog = null
flea = null
person = null
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

describe 'BaseModel', ->
  beforeEach ->
    sharedSetup()

  describe 'class variables', ->
    it 'indices', ->
      expect(DogModel.indices).toEqual(['ownerId'])
      expect(FleaModel.indices).toEqual(['dogId'])

    it 'singular', ->
      expect(DogModel.singular).toEqual('dog')
      expect(FleaModel.singular).toEqual('flea')

    it 'plural', ->
      expect(DogModel.plural).toEqual('doggies')
      expect(FleaModel.plural).toEqual('fleas')

    it 'serializableAttributes', ->
      expect(DogModel.serializableAttributes).toEqual(['id', 'name', 'ownerId'])
      expect(FleaModel.serializableAttributes).toEqual(['letter', 'biting'])
      expect(PersonModel.serializableAttributes).toEqual(null)

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

  describe 'serialize', ->
    beforeEach ->
      dog = recordStore.doggies.create(id: 1, name: 'ruff', isFluffy: true, ownerId: 1)
      flea = recordStore.fleas.create(dogId: 1)
      person = recordStore.people.create(id: 1, name: 'Curella', isWacky: 'always', bornAt: moment("2010-10-20 4:30 +0000", "YYYY-MM-DD HH:mm Z"))

    it 'only serializes specified attributes', ->
      expect(_.keys dog.serialize()['dog']).toEqual(['id', 'name', 'owner_id'])
      expect(_.keys flea.serialize()['flea']).toEqual(['letter', 'biting'])

    it 'serializes all attributesNames if no serializableAttributes specified', ->
      expect(_.keys person.serialize()['person']).toEqual(['age', 'name', 'id', 'is_wacky', 'born_at'])

    it 'formats moments into ISO date format', ->
      expect(person.serialize()['person']['born_at']).toEqual("2010-10-20T04:30:00+00:00")

describe 'recordsInterface', ->
  beforeEach ->
    sharedSetup()

  describe 'build', ->
    beforeEach ->
      dog = recordStore.doggies.build(id: 42)

    it 'builds record with default values', ->
      expect(dog.isFluffy).toBe(true)

    it 'does not insert into collection', ->
      expect(recordStore.doggies.find(42)).toBe(undefined)

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

  describe 'remove', ->
    beforeEach ->
      dog = recordStore.doggies.create(id: 43)

    it 'removes record from recordStore', ->
      dog.remove()
      expect(recordStore.doggies.find(43)).toBe(undefined)


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

  describe 'find', ->
    beforeEach ->
      dog = recordStore.doggies.create(id: 1, key: 'a')

    it 'looks up item by id', ->
      expect(recordStore.doggies.find(1).id).toEqual(dog.id)

    it 'returns null if nothing found for single', ->
      expect(recordStore.doggies.find(7)).toBe(undefined)

    it 'returns [] if nothing found for many', ->
      expect(recordStore.doggies.find([7]).length).toBe(0)

    it 'looks up item by key', ->
      expect(recordStore.doggies.find('a').key).toEqual(dog.key)

    it 'looks up items by ids', ->
      expect(recordStore.doggies.find([1])[0].id).toBe(1)

    it 'looks up items by keys', ->
      expect(recordStore.doggies.find(['a'])[0].key).toBe('a')

    it 'performs complex find when given object with many conditions', ->
      recordStore.doggies.create(id: 5, smellsBad: true)
      goodDog1 = recordStore.doggies.create(id: 6, smellsBad: false)
      recordStore.doggies.create(id: 7, smellsBad: true)
      goodDog2 = recordStore.doggies.create(id: 8, smellsBad: false)

      records = recordStore.doggies.find({'id': {'$gt': 5}, 'smellsBad': false})
      expect(records).toContain(goodDog1, goodDog2)
      expect(records.length).toBe(2)

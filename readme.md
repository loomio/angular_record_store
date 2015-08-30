![travis build badge](https://travis-ci.org/loomio/angular_record_store.svg)

# RecordStore
## A Rails/ActiveRecord like ORM for your AngularJS project

Have you heard of [LokiJS](http://lokijs.org/)? It's a javascript
database library that behaves a lot like MongoDB. It's built with a focus on performance and has great querying and indexing features. I reckon it's really neat.

Have you heard of [Active Model Serializers](https://github.com/rails-api/active_model_serializers)? It's a Rails JSON library for serializing your ActiveRecord models to Javascript. It makes it easy to specify how to serialize a record and it's relationships into JSON. It's a bit of a weirdo library in that the 0.8 branch was really good, the 0.9 branch was terrible and it's not super clear if the 1.0 branch is ready to use yet.. I've not tried it yet because 0.8 does the job.

That's where this ORM comes in. If you have a Rails app that serializes
it's records with AMS then this allows you to define your models on your client so
you can use them kind of like you did on the server side.

Here is a Coffeescript example of a client side model definition:

```coffee
class DogModel extends BaseModel
  @singular: 'dog'        # term for single (required)
  @plural: 'dogs'         # term for many (required)
  @indices: ['ownerId']   # index these columns for fast lookup

  defaultValues: ->       # fn returning attributes for new records
    name: null
    age: 0
    isFluffy: true

  relationships: ->       # describe the relationships with other records
    @hasMany 'fleas',     # creates method dog.fleas() so you can retrieve associated flea records.
                          # optional arguments available (defaults shown)
      from: 'fleas'       # collection that the associated records live in
      with: 'dogId'       # foreign key
      of: 'id'            # source key
      sortBy: 'letter'    # optional sorting (not default acutally)
      sortDesc: true      # But wait there's more! Chain anything from http://lokijs.org/#/docs#views

    @belongsTo 'owner',   # creates dog.owner() 
      from: 'people'      # owner is a person record in the people collection
      by: 'ownerId'       # by: 'ownerId', of: 'id' are the defaults
      of: 'id'            # in this case. only specified here as example

  ownerName: ->           # add any model methods you wish
    @owner.name()         # this gives you dog.ownerName()

  scratchSelf: ->
    _.each _.sample(@fleas(), 5), (flea) -> # lodash is available for you
      flea.awaken()

``` 

Other things I really like about my library:
  - Built specifically to work with Active Model Serializer with rails snake_case -> camel case
  - withs with active model serializers - highlight embed_ids
  - only ever one version of a record.. single source of truth
  - rails/ActiveRecord like relationship declarations: hasMany, belongsTo
  - makes relationships and computed attributes and generally being a model really easy.
  - restfulClient makes http requests easy

To maybe do:
  - automatically add index columns when specifying relationships

To find out how to use this for real, you should read the files in /test

To compile files from src to dist: npm run build
To run the tests: npm test

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

```
class DogModel extends BaseModel          # and returning your model class
  @singular: 'dog'                        # term for single *required*
  @plural: 'dogs'                      # term for many *required*
  @indices: ['ownerId']                   # any attributes often used for lookup

  defaultValues: ->                       # fn returning a object with default values for new records
    name: null                            # i think this is a good way to define both attributeNames and default values
    age: 0
    isFluffy: true

  relationships: ->                          # describe the relationships with other records
    @hasMany 'fleas',                         # creates a fn fleas that returns all flea records where dog.id == flea.dogId
      sortBy: 'letter'
      sortDesc: true

    @belongsTo 'owner',                       # sets up owner: -> Records.users.find(@ownerId)
      from: 'people'                          # all parameters required for now
      by: 'ownerId'

  ownerName: ->
    @owner.name()                            # add any functions you wish

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


To build:
npm run test

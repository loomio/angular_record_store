(function(f){if(typeof exports==="object"&&typeof module!=="undefined"){module.exports=f()}else if(typeof define==="function"&&define.amd){define([],f)}else{var g;if(typeof window!=="undefined"){g=window}else if(typeof global!=="undefined"){g=global}else if(typeof self!=="undefined"){g=self}else{g=this}g.AngularRecordStore = f()}})(function(){var define,module,exports;return (function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);var f=new Error("Cannot find module '"+o+"'");throw f.code="MODULE_NOT_FOUND",f}var l=n[o]={exports:{}};t[o][0].call(l.exports,function(e){var n=t[o][1][e];return s(n?n:e)},l,l.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s})({1:[function(require,module,exports){
var BaseModel, _, moment, utils,
  bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

_ = window._;

moment = window.moment;

utils = require('./utils.coffee');

module.exports = BaseModel = (function() {
  BaseModel.singular = 'undefinedSingular';

  BaseModel.plural = 'undefinedPlural';

  BaseModel.uniqueIndices = ['id'];

  BaseModel.indices = [];

  BaseModel.searchableFields = [];

  BaseModel.serializableAttributes = null;

  BaseModel.serializationRoot = null;

  BaseModel.apiEndPoint = null;

  BaseModel.memoize = [];

  BaseModel.paginate = function(opts) {
    if (opts == null) {
      opts = {};
    }
    if (!(opts.last && opts.pageSize)) {
      console.log('Pagination missing required options! Please provide last, and pageSize params');
    }
    return function(current, mapFn) {
      var first, last, pageSize, ref, result;
      if (mapFn == null) {
        mapFn = (function(v, k) {
          return [k, v];
        });
      }
      ref = [this[opts.first] || 0, this[opts.last], opts.pageSize], first = ref[0], last = ref[1], pageSize = ref[2];
      current = current || first;
      result = {};
      if (current > first) {
        result.prev = _.max([current - pageSize, first]);
      }
      if (current + pageSize <= last) {
        result.next = current + pageSize;
      }
      return _.object(_.map(result, mapFn));
    };
  };

  function BaseModel(recordsInterface, attributes) {
    if (attributes == null) {
      attributes = {};
    }
    this.save = bind(this.save, this);
    this.beforeRemove = bind(this.beforeRemove, this);
    this.beforeDestroy = bind(this.beforeDestroy, this);
    this.destroy = bind(this.destroy, this);
    this.remove = bind(this.remove, this);
    this.inCollection = bind(this.inCollection, this);
    this.processing = false;
    this._version = 0;
    this.attributeNames = [];
    this.setErrors();
    Object.defineProperty(this, 'recordsInterface', {
      value: recordsInterface,
      enumerable: false
    });
    Object.defineProperty(this, 'recordStore', {
      value: recordsInterface.recordStore,
      enumerable: false
    });
    Object.defineProperty(this, 'remote', {
      value: recordsInterface.remote,
      enumerable: false
    });
    this.update(this.defaultValues());
    this.update(attributes);
    if (this.relationships != null) {
      this.buildRelationships();
    }
    this.applyMemoization();
    this.afterConstruction();
  }

  BaseModel.prototype.applyMemoization = function() {
    return _.each(this.constructor.memoize, (function(_this) {
      return function(name) {
        var func;
        func = _this[name];
        return _this[name] = _this.recordStore.memoize(func, _this);
      };
    })(this));
  };

  BaseModel.prototype.bumpVersion = function() {
    return this._version = this._version + 1;
  };

  BaseModel.prototype.afterConstruction = function() {};

  BaseModel.prototype.defaultValues = function() {
    return {};
  };

  BaseModel.prototype.clone = function() {
    var cloneAttributes, cloneRecord;
    cloneAttributes = _.transform(this.attributeNames, (function(_this) {
      return function(clone, attr) {
        if (_.isArray(_this[attr])) {
          clone[attr] = _this[attr].slice(0);
        } else {
          clone[attr] = _this[attr];
        }
        return true;
      };
    })(this));
    cloneRecord = new this.constructor(this.recordsInterface, cloneAttributes);
    cloneRecord.clonedFrom = this;
    return cloneRecord;
  };

  BaseModel.prototype.inCollection = function() {
    return this['$loki'];
  };

  BaseModel.prototype.update = function(attributes) {
    return this.baseUpdate(attributes);
  };

  BaseModel.prototype.baseUpdate = function(attributes) {
    this.bumpVersion();
    this.attributeNames = _.union(this.attributeNames, _.keys(attributes));
    _.assign(this, attributes);
    if (this.inCollection()) {
      return this.recordsInterface.collection.update(this);
    }
  };

  BaseModel.prototype.attributeIsModified = function(attributeName) {
    var current, original;
    if (this.clonedFrom == null) {
      return false;
    }
    original = this.clonedFrom[attributeName];
    current = this[attributeName];
    if (utils.isTimeAttribute(attributeName)) {
      return !(original === current || current.isSame(original));
    } else {
      return original !== current;
    }
  };

  BaseModel.prototype.modifiedAttributes = function() {
    if (this.clonedFrom == null) {
      return [];
    }
    return _.filter(this.attributeNames, (function(_this) {
      return function(name) {
        return _this.attributeIsModified(name);
      };
    })(this));
  };

  BaseModel.prototype.isModified = function() {
    if (this.clonedFrom == null) {
      return false;
    }
    return this.modifiedAttributes().length > 0;
  };

  BaseModel.prototype.serialize = function() {
    return this.baseSerialize();
  };

  BaseModel.prototype.baseSerialize = function() {
    var data, paramKey, wrapper;
    wrapper = {};
    data = {};
    paramKey = _.snakeCase(this.constructor.serializationRoot || this.constructor.singular);
    _.each(this.constructor.serializableAttributes || this.attributeNames, (function(_this) {
      return function(attributeName) {
        var camelName, snakeName;
        snakeName = _.snakeCase(attributeName);
        camelName = _.camelCase(attributeName);
        if (utils.isTimeAttribute(camelName)) {
          data[snakeName] = _this[camelName].utc().format();
        } else {
          data[snakeName] = _this[camelName];
        }
        return true;
      };
    })(this));
    wrapper[paramKey] = data;
    return wrapper;
  };

  BaseModel.prototype.relationships = function() {};

  BaseModel.prototype.buildRelationships = function() {
    this.views = {};
    return this.relationships();
  };

  BaseModel.prototype.hasMany = function(name, userArgs) {
    var args;
    if (userArgs == null) {
      userArgs = {};
    }
    args = _.defaults(userArgs, {
      from: name,
      "with": this.constructor.singular + 'Id',
      of: 'id',
      dynamicView: true
    });
    return this[name] = args.dynamicView ? (function(_this) {
      return function() {
        return _this.buildView(_this.constructor.singular + "_" + (_this.keyOrId()) + "_" + name, args).data();
      };
    })(this) : (function(_this) {
      return function() {
        var obj;
        return _this.recordStore[args.from].find((
          obj = {},
          obj["" + args["with"]] = _this[args.of],
          obj
        ));
      };
    })(this);
  };

  BaseModel.prototype.buildView = function(viewName, args) {
    var obj;
    if (args == null) {
      args = {};
    }
    if (!this.views[viewName]) {
      this.views[viewName] = this.recordStore[args.from].collection.addDynamicView(viewName);
      this.views[viewName].applyFind((
        obj = {},
        obj["" + args["with"]] = this[args.of],
        obj
      ));
      if (args.sortBy) {
        this.views[viewName].applySimpleSort(args.sortBy, args.sortDesc);
      }
    }
    return this.views[viewName];
  };

  BaseModel.prototype.belongsTo = function(name, userArgs) {
    var args, defaults;
    defaults = {
      from: name + 's',
      by: name + 'Id'
    };
    args = _.assign(defaults, userArgs);
    return this[name] = (function(_this) {
      return function() {
        return _this.recordStore[args.from].find(_this[args.by]);
      };
    })(this);
  };

  BaseModel.prototype.translationOptions = function() {};

  BaseModel.prototype.isNew = function() {
    return this.id == null;
  };

  BaseModel.prototype.keyOrId = function() {
    if (this.key != null) {
      return this.key;
    } else {
      return this.id;
    }
  };

  BaseModel.prototype.remove = function() {
    this.beforeRemove();
    if (this.inCollection()) {
      return this.recordsInterface.collection.remove(this);
    }
  };

  BaseModel.prototype.destroy = function() {
    this.processing = true;
    this.beforeDestroy();
    this.remove();
    return this.remote.destroy(this.keyOrId()).then((function(_this) {
      return function() {
        return _this.processing = false;
      };
    })(this));
  };

  BaseModel.prototype.beforeDestroy = function() {};

  BaseModel.prototype.beforeRemove = function() {};

  BaseModel.prototype.save = function() {
    var saveFailure, saveSuccess;
    this.processing = true;
    saveSuccess = (function(_this) {
      return function(records) {
        _this.processing = false;
        _this.clonedFrom = void 0;
        return records;
      };
    })(this);
    saveFailure = (function(_this) {
      return function(errors) {
        _this.processing = false;
        _this.setErrors(errors);
        throw errors;
      };
    })(this);
    if (this.isNew()) {
      return this.remote.create(this.serialize()).then(saveSuccess, saveFailure);
    } else {
      return this.remote.update(this.keyOrId(), this.serialize()).then(saveSuccess, saveFailure);
    }
  };

  BaseModel.prototype.clearErrors = function() {
    return this.errors = {};
  };

  BaseModel.prototype.setErrors = function(errorList) {
    if (errorList == null) {
      errorList = [];
    }
    this.errors = {};
    return _.each(errorList, (function(_this) {
      return function(errors, key) {
        return _this.errors[_.camelCase(key)] = errors;
      };
    })(this));
  };

  BaseModel.prototype.isValid = function() {
    return this.errors.length > 0;
  };

  return BaseModel;

})();


},{"./utils.coffee":6}],2:[function(require,module,exports){
var _, utils;

_ = window._;

utils = require('./utils.coffee');

module.exports = function(RestfulClient, $q) {
  var BaseRecordsInterface;
  return BaseRecordsInterface = (function() {
    BaseRecordsInterface.prototype.model = 'undefinedModel';

    function BaseRecordsInterface(recordStore) {
      this.baseConstructor(recordStore);
    }

    BaseRecordsInterface.prototype.baseConstructor = function(recordStore) {
      this.recordStore = recordStore;
      this.collection = this.recordStore.db.addCollection(this.model.plural, {
        indices: this.model.indices
      });
      _.each(this.model.uniqueIndices, (function(_this) {
        return function(name) {
          return _this.collection.ensureUniqueIndex(name);
        };
      })(this));
      this.remote = new RestfulClient(this.model.apiEndPoint || this.model.plural);
      this.remote.onSuccess = (function(_this) {
        return function(response) {
          return _this.recordStore["import"](response.data);
        };
      })(this);
      return this.remote.onFailure = function(response) {
        console.log('request failure!', response);
        throw response;
      };
    };

    BaseRecordsInterface.prototype.all = function() {
      return this.collection.data;
    };

    BaseRecordsInterface.prototype.build = function(attributes) {
      var record;
      if (attributes == null) {
        attributes = {};
      }
      return record = new this.model(this, attributes);
    };

    BaseRecordsInterface.prototype.create = function(attributes) {
      var record;
      if (attributes == null) {
        attributes = {};
      }
      record = this.build(attributes);
      this.collection.insert(record);
      return record;
    };

    BaseRecordsInterface.prototype.fetch = function(args) {
      return this.remote.fetch(args);
    };

    BaseRecordsInterface.prototype.importJSON = function(json) {
      return this["import"](utils.parseJSON(json));
    };

    BaseRecordsInterface.prototype["import"] = function(attributes) {
      var record;
      if (attributes.key != null) {
        record = this.find(attributes.key);
      }
      if ((attributes.id != null) && (record == null)) {
        record = this.find(attributes.id);
      }
      if (record) {
        record.update(attributes);
      } else {
        record = this.create(attributes);
      }
      this.afterImport(record);
      return record;
    };

    BaseRecordsInterface.prototype.afterImport = function(record) {};

    BaseRecordsInterface.prototype.findOrFetchById = function(id, params) {
      var deferred, promise, record;
      if (params == null) {
        params = {};
      }
      deferred = $q.defer();
      promise = this.remote.fetchById(id, params).then((function(_this) {
        return function() {
          return _this.find(id);
        };
      })(this));
      if (record = this.find(id)) {
        deferred.resolve(record);
      } else {
        deferred.resolve(promise);
      }
      return deferred.promise;
    };

    BaseRecordsInterface.prototype.find = function(q) {
      var chain;
      if (q === null || q === void 0) {
        return void 0;
      } else if (_.isNumber(q)) {
        return this.findById(q);
      } else if (_.isString(q)) {
        return this.findByKey(q);
      } else if (_.isArray(q)) {
        if (q.length === 0) {
          return [];
        } else if (_.isString(q[0])) {
          return this.findByKeys(q);
        } else if (_.isNumber(q[0])) {
          return this.findByIds(q);
        }
      } else {
        chain = this.collection.chain();
        _.each(_.keys(q), function(key) {
          var obj;
          chain.find((
            obj = {},
            obj["" + key] = q[key],
            obj
          ));
          return true;
        });
        return chain.data();
      }
    };

    BaseRecordsInterface.prototype.findById = function(id) {
      return this.collection.by('id', id);
    };

    BaseRecordsInterface.prototype.findByKey = function(key) {
      if (this.collection.constraints.unique['key'] != null) {
        return this.collection.by('key', key);
      } else {
        return this.collection.findOne({
          key: key
        });
      }
    };

    BaseRecordsInterface.prototype.findByIds = function(ids) {
      return this.collection.find({
        id: {
          '$in': ids
        }
      });
    };

    BaseRecordsInterface.prototype.findByKeys = function(keys) {
      return this.collection.find({
        key: {
          '$in': keys
        }
      });
    };

    return BaseRecordsInterface;

  })();
};


},{"./utils.coffee":6}],3:[function(require,module,exports){
module.exports = {
  RecordStoreFn: function() {
    return require('./record_store.coffee');
  },
  BaseModelFn: function() {
    return require('./base_model.coffee');
  },
  BaseRecordsInterfaceFn: require('./base_records_interface.coffee'),
  RestfulClientFn: require('./restful_client.coffee')
};


},{"./base_model.coffee":1,"./base_records_interface.coffee":2,"./record_store.coffee":4,"./restful_client.coffee":5}],4:[function(require,module,exports){
var RecordStore, _;

_ = window._;

module.exports = RecordStore = (function() {
  function RecordStore(db) {
    this.db = db;
    this.collectionNames = [];
  }

  RecordStore.prototype.addRecordsInterface = function(recordsInterfaceClass) {
    var name, recordsInterface;
    recordsInterface = new recordsInterfaceClass(this);
    name = recordsInterface.model.plural;
    this[_.camelCase(name)] = recordsInterface;
    return this.collectionNames.push(name);
  };

  RecordStore.prototype["import"] = function(data) {
    this.bumpVersion();
    _.each(this.collectionNames, (function(_this) {
      return function(name) {
        var camelName, snakeName;
        snakeName = _.snakeCase(name);
        camelName = _.camelCase(name);
        if (data[snakeName] != null) {
          return _.each(data[snakeName], function(recordData) {
            return _this[camelName].importJSON(recordData);
          });
        }
      };
    })(this));
    return data;
  };

  RecordStore.prototype.bumpVersion = function() {
    return this._version = (this._version || 0) + 1;
  };

  RecordStore.prototype.memoize = function(func, obj) {
    var cache;
    cache = {};
    obj = obj || this;
    return function() {
      var args, key;
      args = Array.prototype.slice.call(arguments);
      key = "" + obj._version + (args.join());
      if (cache[key] != null) {
        return cache[key];
      } else {
        return cache[key] = func.apply(this, arguments);
      }
    };
  };

  return RecordStore;

})();


},{}],5:[function(require,module,exports){
var _;

_ = window._;

module.exports = function($http, Upload) {
  var RestfulClient;
  return RestfulClient = (function() {
    RestfulClient.prototype.defaultParams = {};

    RestfulClient.prototype.apiPrefix = "api/v1";

    RestfulClient.prototype.onSuccess = function(response) {
      return response;
    };

    RestfulClient.prototype.onFailure = function(response) {
      throw response;
    };

    function RestfulClient(resourcePlural) {
      this.processing = [];
      this.resourcePlural = _.snakeCase(resourcePlural);
    }

    RestfulClient.prototype.buildUrl = function(path, params) {
      var encodeParams;
      path = _.compact([this.apiPrefix, this.resourcePlural, path]).join('/');
      if (params == null) {
        return path;
      }
      encodeParams = function(params) {
        return _.map(_.keys(params), function(key) {
          return encodeURIComponent(key) + "=" + encodeURIComponent(params[key]);
        }).join('&');
      };
      return path + "?" + encodeParams(params);
    };

    RestfulClient.prototype.memberPath = function(id, action) {
      return _.compact([id, action]).join('/');
    };

    RestfulClient.prototype.fetchById = function(id, params) {
      if (params == null) {
        params = {};
      }
      return this.getMember(id, '', params);
    };

    RestfulClient.prototype.fetch = function(arg) {
      var params, path;
      params = arg.params, path = arg.path;
      return this.get(path || '', params);
    };

    RestfulClient.prototype.get = function(path, params) {
      return $http.get(this.buildUrl(path, _.merge({}, this.defaultParams, params))).then(this.onSuccess, this.onFailure);
    };

    RestfulClient.prototype.post = function(path, params) {
      return $http.post(this.buildUrl(path), _.merge({}, this.defaultParams, params)).then(this.onSuccess, this.onFailure);
    };

    RestfulClient.prototype.patch = function(path, params) {
      return $http.patch(this.buildUrl(path), _.merge({}, this.defaultParams, params)).then(this.onSuccess, this.onFailure);
    };

    RestfulClient.prototype["delete"] = function(path, params) {
      return $http["delete"](this.buildUrl(path), _.merge({}, this.defaultParams, params)).then(this.onSuccess, this.onFailure);
    };

    RestfulClient.prototype.postMember = function(keyOrId, action, params) {
      return this.post(this.memberPath(keyOrId, action), params);
    };

    RestfulClient.prototype.patchMember = function(keyOrId, action, params) {
      return this.patch(this.memberPath(keyOrId, action), params);
    };

    RestfulClient.prototype.getMember = function(keyOrId, action, params) {
      if (action == null) {
        action = '';
      }
      return this.get(this.memberPath(keyOrId, action), params);
    };

    RestfulClient.prototype.create = function(params) {
      return this.post('', params);
    };

    RestfulClient.prototype.update = function(id, params) {
      return this.patch(id, params);
    };

    RestfulClient.prototype.destroy = function(id, params) {
      return this["delete"](id, params);
    };

    RestfulClient.prototype.upload = function(path, file, params, onProgress) {
      var upload;
      if (params == null) {
        params = {};
      }
      upload = Upload.upload(_.merge(params, {
        url: this.buildUrl(path),
        headers: {
          'Content-Type': false
        },
        file: file
      })).progress(onProgress);
      upload.then(this.onSuccess, this.onFailure);
      return upload;
    };

    return RestfulClient;

  })();
};


},{}],6:[function(require,module,exports){
var Utils;

module.exports = new (Utils = (function() {
  function Utils() {}

  Utils.prototype.transformKeys = function(attributes, transformFn) {
    var result;
    result = {};
    _.each(_.keys(attributes), function(key) {
      result[transformFn(key)] = attributes[key];
      return true;
    });
    return result;
  };

  Utils.prototype.parseJSON = function(json) {
    var attributes;
    attributes = this.transformKeys(json, _.camelCase);
    _.each(_.keys(attributes), (function(_this) {
      return function(name) {
        if (attributes[name] != null) {
          if (_this.isTimeAttribute(name) && moment(attributes[name]).isValid()) {
            attributes[name] = moment(attributes[name]);
          } else {
            attributes[name] = attributes[name];
          }
        }
        return true;
      };
    })(this));
    return attributes;
  };

  Utils.prototype.isTimeAttribute = function(attributeName) {
    return /At$/.test(attributeName);
  };

  return Utils;

})());


},{}]},{},[3])(3)
});
(function(f){if(typeof exports==="object"&&typeof module!=="undefined"){module.exports=f()}else if(typeof define==="function"&&define.amd){define([],f)}else{var g;if(typeof window!=="undefined"){g=window}else if(typeof global!=="undefined"){g=global}else if(typeof self!=="undefined"){g=self}else{g=this}g.AngularRecordStore = f()}})(function(){var define,module,exports;return (function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);var f=new Error("Cannot find module '"+o+"'");throw f.code="MODULE_NOT_FOUND",f}var l=n[o]={exports:{}};t[o][0].call(l.exports,function(e){var n=t[o][1][e];return s(n?n:e)},l,l.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s})({1:[function(require,module,exports){
var BaseModel, _, moment,
  bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

_ = window._;

moment = window.moment;

module.exports = BaseModel = (function() {
  var isTimeAttribute, transformKeys;

  BaseModel.singular = 'undefinedSingular';

  BaseModel.plural = 'undefinedPlural';

  BaseModel.indices = [];

  BaseModel.attributeNames = null;

  BaseModel.searchableFields = [];

  function BaseModel(recordsInterface, data, postInitializeData) {
    if (postInitializeData == null) {
      postInitializeData = {};
    }
    this.saveFailure = bind(this.saveFailure, this);
    this.saveSuccess = bind(this.saveSuccess, this);
    this.destroy = bind(this.destroy, this);
    this.save = bind(this.save, this);
    if (this.constructor.attributeNames == null) {
      this.constructor.attributeNames = [];
    }
    this.setErrors();
    this.processing = false;
    Object.defineProperty(this, 'recordsInterface', {
      value: recordsInterface,
      enumerable: false
    });
    Object.defineProperty(this, 'recordStore', {
      value: recordsInterface.recordStore,
      enumerable: false
    });
    Object.defineProperty(this, 'restfulClient', {
      value: recordsInterface.restfulClient,
      enumerable: false
    });
    this.initialize(data);
    _.merge(this, postInitializeData);
    if ((this.setupViews != null) && (this.id != null)) {
      this.setupViews();
    }
  }

  BaseModel.prototype.defaultValues = function() {
    return {};
  };

  BaseModel.prototype.initialize = function(data) {
    return this.baseInitialize(data);
  };

  BaseModel.prototype.baseInitialize = function(data) {
    this.updateFromJSON(this.defaultValues());
    return this.updateFromJSON(data);
  };

  BaseModel.prototype.clone = function() {
    var attrs, cloneRecord;
    attrs = _.reduce(this.constructor.attributeNames, (function(_this) {
      return function(clone, attr) {
        clone[attr] = _this[attr];
        return clone;
      };
    })(this), {});
    cloneRecord = new this.constructor(this.recordsInterface, attrs, {
      id: this.id,
      key: this.key
    });
    cloneRecord._clonedFrom = this;
    return cloneRecord;
  };

  BaseModel.prototype.update = function(data) {
    return this.updateFromJSON(data);
  };

  transformKeys = function(data, transformFn) {
    var newData;
    newData = {};
    _.each(_.keys(data), function(key) {
      newData[transformFn(key)] = data[key];
    });
    return newData;
  };

  isTimeAttribute = function(attributeName) {
    return /At$/.test(attributeName);
  };

  BaseModel.prototype.attributeIsModified = function(attributeName) {
    var current, original;
    if (this._clonedFrom == null) {
      return false;
    }
    original = this._clonedFrom[attributeName];
    current = this[attributeName];
    if (isTimeAttribute(attributeName)) {
      return !(original === current || current.isSame(original));
    } else {
      return original !== current;
    }
  };

  BaseModel.prototype.modifiedAttributes = function() {
    if (this._clonedFrom == null) {
      return [];
    }
    return _.filter(this.constructor.attributeNames, (function(_this) {
      return function(name) {
        return _this.attributeIsModified(name);
      };
    })(this));
  };

  BaseModel.prototype.isModified = function() {
    if (this._clonedFrom == null) {
      return false;
    }
    return this.modifiedAttributes().length > 0;
  };

  BaseModel.prototype.updateFromJSON = function(jsonData) {
    var data;
    data = transformKeys(jsonData, _.camelCase);
    this.scrapeAttributeNames(data);
    return this.importData(data, this);
  };

  BaseModel.prototype.scrapeAttributeNames = function(data) {
    return _.each(_.keys(data), (function(_this) {
      return function(key) {
        if (!_.contains(_this.constructor.attributeNames, key)) {
          _this.constructor.attributeNames.push(key);
        }
      };
    })(this));
  };

  BaseModel.prototype.importData = function(data, dest) {
    return _.each(_.keys(data), (function(_this) {
      return function(key) {
        if (data[key] != null) {
          if (isTimeAttribute(key) && moment(data[key]).isValid()) {
            dest[key] = moment(data[key]);
          } else {
            dest[key] = data[key];
          }
        } else {
          data[key] = null;
        }
      };
    })(this));
  };

  BaseModel.prototype.serialize = function() {
    return this.baseSerialize();
  };

  BaseModel.prototype.baseSerialize = function() {
    var data, paramKey, wrapper;
    wrapper = {};
    data = {};
    paramKey = _.snakeCase(this.constructor.singular);
    _.each(window.Loomio.permittedParams[paramKey], (function(_this) {
      return function(attributeName) {
        data[_.snakeCase(attributeName)] = _this[_.camelCase(attributeName)];
        return true;
      };
    })(this));
    wrapper[paramKey] = data;
    return wrapper;
  };

  BaseModel.prototype.addView = function(collectionName, viewName) {
    return this.recordStore[collectionName].collection.addDynamicView(this.id + "-" + viewName);
  };

  BaseModel.prototype.setupViews = function() {};

  BaseModel.prototype.setupView = function(view, sort, desc) {
    var idOption, viewName;
    viewName = view + "View";
    idOption = {};
    idOption[this.constructor.singular + "Id"] = this.id;
    this[viewName] = this.recordStore[view].collection.addDynamicView(this.viewName());
    this[viewName].applyFind(idOption);
    this[viewName].applyFind({
      id: {
        $gt: 0
      }
    });
    return this[viewName].applySimpleSort(sort || 'createdAt', desc);
  };

  BaseModel.prototype.translationOptions = function() {};

  BaseModel.prototype.viewName = function() {
    return "" + this.constructor.plural + this.id;
  };

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

  BaseModel.prototype.save = function() {
    this.setErrors();
    if (this.processing) {
      console.log("save returned, already processing:", this);
      return;
    }
    this.processing = true;
    if (this.isNew()) {
      return this.restfulClient.create(this.serialize()).then(this.saveSuccess, this.saveFailure);
    } else {
      return this.restfulClient.update(this.keyOrId(), this.serialize()).then(this.saveSuccess, this.saveFailure);
    }
  };

  BaseModel.prototype.destroy = function() {
    this.processing = true;
    return this.restfulClient.destroy(this.keyOrId()).then((function(_this) {
      return function() {
        _this.processing = false;
        return _this.recordsInterface.remove(_this);
      };
    })(this), function() {});
  };

  BaseModel.prototype.saveSuccess = function(records) {
    this._clonedFrom = void 0;
    this.processing = false;
    return records;
  };

  BaseModel.prototype.saveFailure = function(errors) {
    this.processing = false;
    this.setErrors(errors);
    throw errors;
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


},{}],2:[function(require,module,exports){
var _;

_ = window._;

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
      this.restfulClient = new RestfulClient(this.model.plural);
      this.latestCache = {};
      this.restfulClient.onSuccess = (function(_this) {
        return function(response) {
          return _this.recordStore["import"](response.data);
        };
      })(this);
      return this.restfulClient.onFailure = function(response) {
        console.log('request failure!', response);
        throw response;
      };
    };

    BaseRecordsInterface.prototype.build = function(data) {
      if (data == null) {
        data = {};
      }
      return new this.model(this, data);
    };

    BaseRecordsInterface.prototype["import"] = function(data) {
      if (data == null) {
        data = {};
      }
      return this.baseImport(data);
    };

    BaseRecordsInterface.prototype.baseImport = function(data) {
      var record;
      if (data == null) {
        data = {};
      }
      if (record = this.find(data.key || data.id)) {
        record.updateFromJSON(data);
      } else {
        this.collection.insert(record = this.build(data));
      }
      return record;
    };

    BaseRecordsInterface.prototype.remove = function(record) {
      return this.collection.remove(record);
    };

    BaseRecordsInterface.prototype.findOrFetchByKey = function(key) {
      var deferred, promise, record;
      deferred = $q.defer();
      promise = this.fetchByKey(key).then((function(_this) {
        return function() {
          return _this.find(key);
        };
      })(this));
      if (record = this.find(key)) {
        deferred.resolve(record);
      } else {
        deferred.resolve(promise);
      }
      return deferred.promise;
    };

    BaseRecordsInterface.prototype.fetchByKey = function(key) {
      return this.restfulClient.getMember(key);
    };

    BaseRecordsInterface.prototype.fetch = function(arg) {
      var cacheKey, lastFetchedAt, params, path;
      params = arg.params, path = arg.path, cacheKey = arg.cacheKey;
      if (cacheKey) {
        lastFetchedAt = this.applyLatestFetch(cacheKey);
        if ((params != null) && (lastFetchedAt != null)) {
          params.since = lastFetchedAt;
        }
      }
      if (path != null) {
        return this.restfulClient.get(path, params);
      } else {
        return this.restfulClient.getCollection(params);
      }
    };

    BaseRecordsInterface.prototype.applyLatestFetch = function(cacheKey) {
      var lastFetchedAt;
      lastFetchedAt = this.latestCache[cacheKey];
      this.latestCache[cacheKey] = moment().toDate();
      return lastFetchedAt;
    };

    BaseRecordsInterface.prototype.where = function(params) {
      return this.collection.chain().find(params).data();
    };

    BaseRecordsInterface.prototype.belongingTo = function(params) {
      return this.collection.addDynamicView(this.viewName(params)).applyFind(params);
    };

    BaseRecordsInterface.prototype.viewName = function(params) {
      return _.keys(params).join() + _.values(params).join();
    };

    BaseRecordsInterface.prototype.find = function(q) {
      if (q === null || q === void 0) {
        return null;
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
        return this.collection.find(q);
      }
    };

    BaseRecordsInterface.prototype.findById = function(id) {
      return this.collection.findOne({
        id: id
      });
    };

    BaseRecordsInterface.prototype.findByKey = function(key) {
      return this.collection.findOne({
        key: key
      });
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

    BaseRecordsInterface.prototype.destroy = function(id) {
      return this.restfulClient.destroy(id);
    };

    return BaseRecordsInterface;

  })();
};


},{}],3:[function(require,module,exports){
module.exports = {
  RecordStore: require('./record_store.coffee'),
  BaseModel: require('./base_model.coffee'),
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
    _.each(this.collectionNames, (function(_this) {
      return function(name) {
        var camelName, snakeName;
        snakeName = _.snakeCase(name);
        camelName = _.camelCase(name);
        if (data[snakeName] != null) {
          return _.each(data[snakeName], function(recordData) {
            return _this[camelName]["import"](recordData);
          });
        }
      };
    })(this));
    return data;
  };

  return RecordStore;

})();


},{}],5:[function(require,module,exports){
var _;

_ = window._;

module.exports = function($http, $upload) {
  var RestfulClient;
  return RestfulClient = (function() {
    RestfulClient.prototype.apiPrefix = "api/v1";

    RestfulClient.prototype.onSuccess = function(response) {
      return response;
    };

    RestfulClient.prototype.onFailure = function(response) {
      throw response;
    };

    function RestfulClient(resourcePlural) {
      this.resourcePlural = _.snakeCase(resourcePlural);
    }

    RestfulClient.prototype.buildUrl = function(url, params) {
      var encodeParams;
      if (params == null) {
        return url;
      }
      encodeParams = function(params) {
        return _.map(_.keys(params), function(key) {
          return encodeURIComponent(key) + "=" + encodeURIComponent(params[key]);
        }).join('&');
      };
      return url + "?" + encodeParams(params);
    };

    RestfulClient.prototype.collectionPath = function() {
      return this.apiPrefix + "/" + this.resourcePlural;
    };

    RestfulClient.prototype.memberPath = function(id, action) {
      if (action != null) {
        return this.apiPrefix + "/" + this.resourcePlural + "/" + id + "/" + action;
      } else {
        return this.apiPrefix + "/" + this.resourcePlural + "/" + id;
      }
    };

    RestfulClient.prototype.customPath = function(path) {
      return this.apiPrefix + "/" + this.resourcePlural + "/" + path;
    };

    RestfulClient.prototype.get = function(path, params) {
      var url;
      url = this.buildUrl(this.customPath(path), params);
      return $http.get(url).then(this.onSuccess, this.onFailure);
    };

    RestfulClient.prototype.post = function(path, params) {
      return $http.post(this.customPath(path), params).then(this.onSuccess, this.onFailure);
    };

    RestfulClient.prototype.upload = function(path, file) {
      return $upload.upload({
        url: this.customPath(path),
        headers: {
          'Content-Type': false
        },
        file: file
      });
    };

    RestfulClient.prototype.postMember = function(keyOrId, action, params) {
      return $http.post(this.memberPath(keyOrId, action), params).then(this.onSuccess, this.onFailure);
    };

    RestfulClient.prototype.patchMember = function(keyOrId, action, params) {
      return $http.patch(this.memberPath(keyOrId, action), params).then(this.onSuccess, this.onFailure);
    };

    RestfulClient.prototype.getMember = function(keyOrId, action) {
      return $http.get(this.memberPath(keyOrId, action)).then(this.onSuccess, this.onFailure);
    };

    RestfulClient.prototype.getCollection = function(params) {
      var url;
      url = this.buildUrl(this.collectionPath(), params);
      return $http.get(url).then(this.onSuccess, this.onFailure);
    };

    RestfulClient.prototype.create = function(params) {
      return $http.post(this.collectionPath(), params).then(this.onSuccess, this.onFailure);
    };

    RestfulClient.prototype.update = function(id, params) {
      return $http.patch(this.memberPath(id), params).then(this.onSuccess, this.onFailure);
    };

    RestfulClient.prototype.destroy = function(id) {
      return $http["delete"](this.memberPath(id)).then(this.onSuccess, this.onFailure);
    };

    return RestfulClient;

  })();
};


},{}]},{},[3])(3)
});
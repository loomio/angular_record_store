(function(f){if(typeof exports==="object"&&typeof module!=="undefined"){module.exports=f()}else if(typeof define==="function"&&define.amd){define([],f)}else{var g;if(typeof window!=="undefined"){g=window}else if(typeof global!=="undefined"){g=global}else if(typeof self!=="undefined"){g=self}else{g=this}g.AngularRecordStore = f()}})(function(){var define,module,exports;return (function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);var f=new Error("Cannot find module '"+o+"'");throw f.code="MODULE_NOT_FOUND",f}var l=n[o]={exports:{}};t[o][0].call(l.exports,function(e){var n=t[o][1][e];return s(n?n:e)},l,l.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s})({1:[function(require,module,exports){
var BaseModel, _, isTimeAttribute, moment,
  bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

_ = window._;

moment = window.moment;

isTimeAttribute = function(attributeName) {
  return /At$/.test(attributeName);
};

module.exports = BaseModel = (function() {
  BaseModel.singular = 'undefinedSingular';

  BaseModel.plural = 'undefinedPlural';

  BaseModel.indices = [];

  BaseModel.searchableFields = [];

  function BaseModel(recordsInterface, attributes) {
    if (attributes == null) {
      attributes = {};
    }
    this.save = bind(this.save, this);
    this.destroy = bind(this.destroy, this);
    this.belongsTo = bind(this.belongsTo, this);
    this.inCollection = false;
    this.processing = false;
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
  }

  BaseModel.prototype.defaultValues = function() {
    return {};
  };

  BaseModel.prototype.clone = function() {
    var cloneAttributes, cloneRecord;
    cloneAttributes = _.transform(this.attributeNames, (function(_this) {
      return function(clone, attr) {
        clone[attr] = _this[attr];
        return true;
      };
    })(this));
    cloneRecord = new this.constructor(this.recordsInterface, cloneAttributes);
    cloneRecord.clonedFrom = this;
    return cloneRecord;
  };

  BaseModel.prototype.update = function(attributes) {
    this.attributeNames = _.union(this.attributeNames, _.keys(attributes));
    _.assign(this, attributes);
    if (this.inCollection) {
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
    if (isTimeAttribute(attributeName)) {
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

  BaseModel.prototype.relationships = function() {};

  BaseModel.prototype.buildRelationships = function() {
    this.views = {};
    return this.relationships();
  };

  BaseModel.prototype.hasMany = function(name, userArgs) {
    var addDynamicView, addFindMethod, args, defaults;
    defaults = {
      from: name,
      "with": this.constructor.singular + 'Id',
      of: 'id',
      dynamicView: true
    };
    args = _.assign(defaults, userArgs);
    addDynamicView = (function(_this) {
      return function() {
        var obj, viewName;
        viewName = _this.constructor.plural + "." + name + "." + (Math.random());
        if (_this.recordStore[args.from] == null) {
          console.log(args.from);
        }
        _this.views[viewName] = _this.recordStore[args.from].collection.addDynamicView(name);
        _this.views[viewName].applyFind((
          obj = {},
          obj["" + args["with"]] = _this[args.of],
          obj
        ));
        if (args.sortBy) {
          _this.views[viewName].applySimpleSort(args.sortBy, args.sortDesc);
        }
        _this.views[viewName];
        return _this[name] = function() {
          return _this.views[viewName].data();
        };
      };
    })(this);
    addFindMethod = (function(_this) {
      return function() {
        return _this[name] = function() {
          var obj;
          if (_this.recordStore[args.from] == null) {
            console.log(args.from);
          }
          return _this.recordStore[args.from].where((
            obj = {},
            obj["" + args["with"]] = _this[args.of],
            obj
          ));
        };
      };
    })(this);
    if (args.dynamicView) {
      return addDynamicView();
    } else {
      return addFindMethod();
    }
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
        if (_this.recordStore[args.from] == null) {
          console.log(args.from);
        }
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

  BaseModel.prototype.destroy = function() {
    if (this.inCollection) {
      this.recordsInterface.collection.remove(this);
    }
    if (!this.isNew()) {
      this.processing = true;
      return this.remote.destroy(this.keyOrId()).then((function(_this) {
        return function() {
          return _this.processing = false;
        };
      })(this));
    }
  };

  BaseModel.prototype.save = function() {
    var saveFailure, saveSuccess;
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
    this.processing = true;
    if (this.isNew) {
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


},{}],2:[function(require,module,exports){
var _, isTimeAttribute, parseJSON, transformKeys;

_ = window._;

transformKeys = function(attributes, transformFn) {
  return _.transform(_.keys(attributes), function(result, key) {
    result[transformFn(key)] = attributes[key];
    return true;
  });
};

parseJSON = function(json) {
  var attributes;
  attributes = transformKeys(json, _.camelCase);
  _.each(_.keys(attributes), function(name) {
    if (attributes[name] != null) {
      if (isTimeAttribute(name) && moment(attributes[name]).isValid()) {
        attributes[name] = moment(attributes[name]);
      } else {
        attributes[name] = attributes[name];
      }
    }
    return true;
  });
  return attributes;
};

isTimeAttribute = function(attributeName) {
  return /At$/.test(attributeName);
};

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
      record.inCollection = true;
      return record;
    };

    BaseRecordsInterface.prototype.fetch = function(args) {
      return this.remote.fetch(args);
    };

    BaseRecordsInterface.prototype.importJSON = function(json) {
      return this["import"](parseJSON(json));
    };

    BaseRecordsInterface.prototype["import"] = function(attributes) {
      var record;
      record = this.find(attributes.key || attributes.id);
      if (record) {
        record.update(attributes);
      } else {
        record = this.create(attributes);
      }
      return record;
    };

    BaseRecordsInterface.prototype.findOrFetchById = function(id) {
      var deferred, promise, record;
      deferred = $q.defer();
      promise = this.remote.fetchById(id).then((function(_this) {
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

    BaseRecordsInterface.prototype.where = function(params) {
      return this.collection.chain().find(params).data();
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
            return _this[camelName].importJSON(recordData);
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
      this.processing = [];
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

    RestfulClient.prototype.fetchById = function(id) {
      return this.getMember(id);
    };

    RestfulClient.prototype.fetch = function(arg) {
      var params, path;
      params = arg.params, path = arg.path;
      if (path != null) {
        return this.get(path, params);
      } else {
        return this.getCollection(params);
      }
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
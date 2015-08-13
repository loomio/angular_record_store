module.exports = (karma) ->
  karma.set
    frameworks: [ 'browserify', 'jasmine' ]
    browsers: ['PhantomJS']

    files: [
      'test/*.coffee'
    ]

    preprocessors:
      'test/*.coffee': [ 'browserify' ]

    reporters: [ 'dots' ]
    browsers: [ 'PhantomJS' ]
    logLevel: 'LOG_DEBUG'
    singleRun: true
    autoWatch: false

    # browserify configuration
    browserify:
      debug: true
